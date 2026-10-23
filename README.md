Ansbile autoinstall CryptoPro, KESL.

Windows in cmd:
wsl -d Ubuntu-24.04 -u root
cd Desktop/ansible-alt
ansible-playbook -i inventory.ini playbook.yml --limit alt -k -K

Linux:
cd /home/user/ansible-alt
ansible-playbook -i inventory.ini playbook.yml
