#!/usr/bin/python
import os
import sys
import subprocess
from jazz_common import get_tfvars_file, replace_tfvars


def add_splunk_config_to_files(parameter_list):
    """
        Add Splunk configuration to terraform.tfvars
        parameter_list = [  sonar_server_elb ,
                            sonar_username,
                            sonar_passwd,
                            sonar_server_public_ip]
     """

    replace_tfvars('sonar_server_elb', parameter_list[0], get_tfvars_file())
    replace_tfvars('sonar_username', parameter_list[1], get_tfvars_file())
    replace_tfvars('sonar_passwd', parameter_list[2], get_tfvars_file())
    replace_tfvars('sonar_server_public_ip', parameter_list[3], get_tfvars_file())
    replace_tfvars('codequality_type', 'sonarqube', get_tfvars_file())
    replace_tfvars('codeq', 1, get_tfvars_file())


def get_add_splunk_config(terraform_folder):
    """
        Get the exisintg Splunk server details from user,
        validate and change the config files.
    """
    os.chdir(terraform_folder)

    # Get Existing Splunk Details form user
    print "\nPlease provide Splunk Details.."
    sonar_server_elb = raw_input(
        "Splunk URL (Please ignore http from URL) :")
    sonar_username = raw_input("Splunk username :")
    sonar_passwd = raw_input("Splunk password :")

    splunk_confirmation = raw_input(
        """\nWould you like to use Splunk [y/n] :""")

    if splunk_confirmation == 'y':
        # Get Splunk public ip
        sonar_server_public_ip = raw_input("Splunk Server PublicIp :")

        # Create paramter list
        parameter_list = [
            sonar_server_elb, sonar_username, sonar_passwd,
            sonar_server_public_ip
        ]

        add_splunk_config_to_files(parameter_list)
