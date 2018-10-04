#!/usr/bin/env python2
import subprocess
import argparse
import os.path
import json
import urllib


class colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


featureName = "Splunk"
configFile = "../../installscripts/cookbooks/jenkins/files/default/jazz-installer-vars.json"
terraformFile = "../../installscripts/jazz-terraform-unix-noinstances/terraform.tfvars"
pushInstallerScript = "installscripts/jazz-terraform-unix-noinstances/scripts/pushInstallervars.sh"


def main():
    subprocess.call(['sudo', 'pip', 'install', 'pyhcl'])
    mainParser = argparse.ArgumentParser()
    mainParser.description = ('Installs the Splunk extension for the Jazz Serverless Development Platform '
                              '(https://github.com/tmobile/jazz)')
    subparsers = mainParser.add_subparsers(help='Installation scenarios', dest='command')

    subparsers.add_parser('install', help='Install feature extension').set_defaults(func=install)

    mainParser.add_argument(
        '--splunk-endpoint',
        help='Specify the splunk endpoint'
    )
    mainParser.add_argument(
        '--splunk-token',
        help='Specify the splunk token'
    )
    mainParser.add_argument(
        '--splunk-index',
        help='Specify the splunk index'
    )
    args = mainParser.parse_args()
    args.func(args)


def install(args):
    print(
        colors.OKGREEN +
        "\nThis will install {0} functionality into your Jazz deployment.\n".format(featureName)
        + colors.ENDC)

    configureSplunk(args, True)


def configureSplunk(args, splunk_enable):
    if not os.path.isfile(configFile):
        print(colors.FAIL +
              'Cannot find the Installer vars json file! No install possible'
              + colors.ENDC)
        return True
    if not args.splunk_endpoint:
        args.splunk_endpoint = raw_input("Please enter the Splunk Endpoint: ")

    if not args.splunk_token:
        args.splunk_token = raw_input("Please enter the Splunk Token: ")

    if not args.splunk_index:
        args.splunk_index = raw_input("Please enter the Splunk Index: ")

    if not args.splunk_endpoint and not args.splunk_token and not args.splunk_index:
        print(colors.FAIL +
              'Cannot proceed! No install possible'
              + colors.ENDC)
        return True
    print(args.splunk_endpoint, args.splunk_token, args.splunk_index)

    replace_config(args)


def replace_config(args):
    # Read in the file
    with open(configFile, 'r') as file:
        filedata = file.read()

    # Replace the target string
    filedata = filedata.replace('{ENABLE_SPLUNK_FEATURE}', 'true')
    filedata = filedata.replace('{SPLUNK_ENDPOINT}', args.splunk_endpoint)
    filedata = filedata.replace('{SPLUNK_TOKEN}', args.splunk_token)
    filedata = filedata.replace('{SPLUNK_INDEX}', args.splunk_index)

    # Write the file out again
    with open(configFile, 'w') as file:
        file.write(filedata)

    # Commit the updated installer vars json into scm jazz build module.
    # Convert terraform.tfvars from main installer to json file
    subprocess.check_call(['hcltool', terraformFile, 'terraformvars.json'])
    with open('./terraformvars.json') as json_file:
        json_data = json.load(json_file)
        os.chdir('../../')
        os.environ['JAZZ_INSTALLER_ROOT'] = os.getcwd()
        subprocess.check_call([
                pushInstallerScript, json_data['scmmap']['scm_username'],
                urllib.quote(json_data['scmmap']['scm_passwd']), json_data['scmmap']['scm_elb'],
                json_data['scmmap']['scm_pathext'], json_data['cognito_pool_username']
                ])


main()
