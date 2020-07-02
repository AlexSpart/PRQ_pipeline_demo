#!/usr/bin/env python3

import glob
import os
import sys
import yaml

folder_param = sys.argv[1]
enabled = sys.argv[2]

if enabled == "0":
    print("Disabled by parameter.")
    sys.exit(0)

if not os.path.isdir(folder_param):
    print("Given folder '" + folder_param + "' does not exist.")
    sys.exit(1)


file_list = glob.glob(folder_param + "/*.tosca")
if len(file_list) == 0:
    print("Found no matching files to process.")
    sys.exit(1)


for file_param in file_list:
  with open(file_param, 'r') as input_file:
    tosca = yaml.full_load(input_file)

  if 'policy_types' in tosca:
    del tosca['policy_types']

  if 'topology_template' in tosca and  'policies' in tosca['topology_template']:
    del tosca['topology_template']['policies']

  with open(file_param, 'w') as output_file:
    yaml.dump(tosca, output_file)

print("Processed", len(file_list), "files.")

