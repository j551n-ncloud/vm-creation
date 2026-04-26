[vault]
vault ansible_host=${vault_ip}

[services]
%{ for name, svc in services ~}
${name} ansible_host=${svc.ip}
%{ endfor ~}

[runners]
%{ for node, runner in runner_lxcs ~}
runner-${node} ansible_host=${runner.ip}
%{ endfor ~}

[all:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
