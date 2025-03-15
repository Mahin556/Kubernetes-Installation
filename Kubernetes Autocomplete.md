# Kubernetes Command Autocompletion

Enable command-line autocompletion for `kubectl` in your terminal.

## Steps to Enable Autocompletion

### Install Bash Completion
```bash
yum install bash-completion -y
```

### Source Bash Completion
```bash
source /usr/share/bash-completion/bash_completion
```

### Enable Kubectl Autocompletion
```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
```

### Store Completion Script Permanently
```bash
kubectl completion bash > /etc/bash_completion.d/kubectl
```

### Apply Changes
Logout and log in again, or run:
```bash
source ~/.bashrc
```

## Verification
To test autocompletion, type:
```bash
kubectl get <TAB>
```
If the setup is correct, you should see available resource suggestions.

## Notes
- Ensure `kubectl` is installed before enabling autocompletion.
- This setup is for Bash users. If you're using Zsh, replace `~/.bashrc` with `~/.zshrc` and use:
  ```bash
  echo 'source <(kubectl completion zsh)' >> ~/.zshrc
  ```
