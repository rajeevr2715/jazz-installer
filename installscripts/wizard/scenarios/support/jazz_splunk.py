#!/usr/bin/python
import os
from jazz_common import get_tfvars_file, replace_tfvars


def add_splunk_config_to_files(parameter_list):
    """
        Add Splunk configuration to terraform.tfvars
        parameter_list = [  splunk_enable ,
                            splunk_endpoint,
                            splunk_token]
     """

    replace_tfvars('splunk_enable', parameter_list[0], get_tfvars_file())
    replace_tfvars('splunk_endpoint', parameter_list[1], get_tfvars_file())
    replace_tfvars('splunk_token', parameter_list[2], get_tfvars_file())
    replace_tfvars('splunk_index', parameter_list[3], get_tfvars_file())


def get_and_add_splunk_config(terraform_folder):
    """
        Get the exisintg Splunk server details from user,
        change the config files.
    """
    os.chdir(terraform_folder)

    # Get Existing Splunk Details form user
    print "\nPlease provide Splunk Details.."

    splunk_confirmation = raw_input(
        """\nWould you like to use Splunk [y/n] :""")

    if splunk_confirmation == 'y':
        # Get Splunk public ip
        splunk_enable = "true"
        splunk_endpoint = raw_input("Splunk Endpoint :")
        splunk_token = raw_input("Splunk Token :")
        splunk_index = raw_input("Splunk Index :")

        # Create paramter list
        parameter_list = [splunk_enable, splunk_endpoint, splunk_token, splunk_index]

        add_splunk_config_to_files(parameter_list)
