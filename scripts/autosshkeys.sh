#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

if [[ ! -d ${HOME}/.ssh ]] \
|| [[ ! -f ${HOME}/.ssh/id_rsa ]] \
|| [[ ! -f ${HOME}/.ssh/id_rsa.pub ]] \
|| [[ ! -f ${HOME}/.ssh/authorized_keys ]]; then
  mkdir -p "${HOME}/.ssh"
  ssh-keygen -q -t rsa -b 4096 -N "" -f ${HOME}/.ssh/id_rsa; 
  cat ${HOME}/.ssh/id_rsa.pub >> ${HOME}/.ssh/authorized_keys
  chown -R "${user}:${group}" "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  chmod 600 "${HOME}/.ssh/id_rsa"
  chmod 600 "${HOME}/.ssh/id_rsa.pub"
  chmod 600 "${HOME}/.ssh/authorized_keys"
fi