import os
import yaml

config_dir = '/etc/netplan/'

for filename in os.listdir(config_dir):
    if filename.endswith('.yaml'):
        file_path = os.path.join(config_dir, filename)
        
        with open(file_path, 'r') as file:
            try:
                config = yaml.safe_load(file)
            except yaml.YAMLError as e:
                print(f"Error parsing {file_path}: {e}")
                continue
        
        # Modify the interfaces in the YAML configuration
        if 'network' in config:
            network_config = config['network']
            
            if 'ethernets' in network_config:
                ethernets = network_config['ethernets']
                for interface in ethernets:
                    ethernets[interface]['optional'] = True
            
            if 'wifis' in network_config:
                wifis = network_config['wifis']
                for interface in wifis:
                    wifis[interface]['optional'] = True
        
        # Write the modified configuration back to the file
        with open(file_path, 'w') as file:
            yaml.dump(config, file)
        
        print(f"Modified {file_path}")

