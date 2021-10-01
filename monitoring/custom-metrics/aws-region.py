#
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
#
import json
import sys

from pkg_resources import resource_filename

region = str(sys.argv[1])

name = None
endpoint_file = resource_filename('botocore', 'data/endpoints.json')
with open(endpoint_file, 'r') as ep_file:
    data = json.load(ep_file)
    for partition in data['partitions']:
        if region in partition['regions']:
            name = partition['regions'][region]['description']
            break

print(name)