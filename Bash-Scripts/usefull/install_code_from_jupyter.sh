#!/bin/bash
VERSION=4.103.2

## 1. Install VC Code into ~/.local/bin

mkdir -p ~/.local/lib ~/.local/bin
curl -fL https://github.com/coder/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-amd64.tar.gz \
  | tar -C ~/.local/lib -xz
mv ~/.local/lib/code-server-$VERSION-linux-amd64 ~/.local/lib/code-server-$VERSION
ln -s ~/.local/lib/code-server-$VERSION/bin/code-server ~/.local/bin/code-server

#PATH="~/.local/bin:$PATH"
#code-server

# 2. install jupyter extensions to launch vscode from Launcher

python -m pip install jupyter-server-proxy jupyter-vscode-proxy

# 3. Edit/Fix configuration settings in vscode Launcher, since vs code is not installed on the system, byt only for your user

## 3.1. determine path of jupyter-vscode-proxy library:
PATH_TO_LIB=$(python -c 'import jupyter_vscode_proxy as jjj; print(jjj.__file__)')

## 3.2. Remove check on existence in path
sed -i 's|raise FileNotFoundError.*|pass|g' ${PATH_TO_LIB}

## 3.3. Change path to full path of code-server
sed -i 's|"code-server",|"'${HOME}'/.local/bin/code-server",|g'

# 4. Restart jupyter hub for changes to take effect
echo "please restart hub from File=>Hub Control Panel"
