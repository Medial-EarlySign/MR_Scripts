#!/bin/bash
VERSION=4.102.1

mkdir -p ~/.local/lib ~/.local/bin
curl -fL https://github.com/coder/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-amd64.tar.gz \
  | tar -C ~/.local/lib -xz
mv ~/.local/lib/code-server-$VERSION-linux-amd64 ~/.local/lib/code-server-$VERSION
ln -s ~/.local/lib/code-server-$VERSION/bin/code-server ~/.local/bin/code-server
PATH="~/.local/bin:$PATH"
code-server

python -m pip install jupyter-server-proxy jupyter-vscode-proxy

#edit $HOME/.local/lib/python3.12/site-packages/jupyter_vscode_proxy/__init__.py
# full path to executable, remove check on existence in path
sed -i 's|raise FileNotFoundError.*|pass|g' $HOME/.local/lib/python3.12/site-packages/jupyter_vscode_proxy/__init__.py
sed -i 's|"code-server",|"$HOME/.local/bin/code-server",|g'

echo "please restart hub from File=>Hub Control Panel"