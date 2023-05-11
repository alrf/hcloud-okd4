#cloud-config

# upgrade packages on boot
package_update: true
packages:
  - curl
  - nginx
  - vim
  - telnet
apt_upgrade: true
apt_reboot_if_required: true

write_files:
  - path: /etc/ssh/sshd_config
    content: |
      # managed by cloud-init
      AddressFamily any
      Port 22

      #HostKey /etc/ssh/ssh_host_dsa_key
      #HostKey /etc/ssh/ssh_host_ecdsa_key
      AcceptEnv LC_*
      Banner none
      ChallengeResponseAuthentication no
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      #ClientAliveCountMax 0
      #ClientAliveInterval 900
      Compression no
      HostKey /etc/ssh/ssh_host_rsa_key
      HostKey /etc/ssh/ssh_host_ed25519_key
      HostbasedAuthentication no
      IgnoreRhosts yes
      KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512
      LogLevel VERBOSE
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
      MaxAuthTries 2
      MaxSessions 10
      MaxStartups 10:30:100
      PasswordAuthentication no
      PermitEmptyPasswords no
      PermitRootLogin without-password
      PrintMotd no
      Protocol 2
      Subsystem sftp /usr/lib/openssh/sftp-server
      SyslogFacility AUTHPRIV
      UseDNS no
      UsePAM yes
      X11Forwarding no
  - path: /etc/nginx/tcpconf.d/okd_lb.conf
    content: |
      # managed by cloud-init
      stream {
          upstream k8s_api_server {
            %{~ for i in split(",",masters) ~}
              server ${i}:6443 fail_timeout=2s;
            %{~ endfor ~}
          }

          upstream machine_config {
            %{~ for i in split(",",masters) ~}
              server ${i}:22623 fail_timeout=2s;
            %{~ endfor ~}
          }

          upstream route_http {
            %{~ for i in split(",",workers) ~}
              server ${i}:80 fail_timeout=2s;
            %{~ endfor ~}
          }

          upstream route_https {
            %{~ for i in split(",",workers) ~}
              server ${i}:443 fail_timeout=2s;
            %{~ endfor ~}
          }

          server {
              listen 6443;
              proxy_pass k8s_api_server;
          }

          server {
              listen 22623;
              proxy_pass machine_config;
          }

          server {
              listen 80;
              proxy_pass route_http;
          }

          server {
              listen 443;
              proxy_pass route_https;
          }
      }

# only run
runcmd:
  - "mkdir -p /etc/nginx/tcpconf.d"
  - "rm -f /etc/nginx/sites-enabled/default"
  - "echo 'include /etc/nginx/tcpconf.d/*;' >> /etc/nginx/nginx.conf"
  - "systemctl restart sshd"
  - "sleep 45 && systemctl restart nginx"
  - "touch /etc/cloud-init.done"

final_message: "The system is finally up, after $UPTIME seconds"

#phone_home:
# url: http://my.example.com/$INSTANCE_ID/
# post: [ pub_key_dsa, pub_key_rsa, pub_key_ecdsa, instance_id ]
