#!/usr/bin/env python2
import subprocess
import argparse
import os.path


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


def main():
    mainParser = argparse.ArgumentParser()
    mainParser.description = ('Installs the Splunk extension for the Jazz Serverless Development Platform '
                              '(https://github.com/tmobile/jazz)')
    subparsers = mainParser.add_subparsers(help='Installation scenarios', dest='command')

    subparsers.add_parser('install', help='Install feature extension').set_defaults(func=install)
    subparsers.add_parser('uninstall', help='Uninstall feature extension').set_defaults(func=uninstall)

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


def uninstall(args):
    print(
        colors.OKGREEN +
        "\nThis will remove {0} functionality from your Jazz deployment.\n".format(featureName)
        + colors.ENDC)

    configureSplunk(args, False)


def configureSplunk(args, splunk_enable):
    if not os.path.isfile('../../ijjnstallscripts/cookbooks/jenkins/files/default/jazz-installer-vars.json'):
        print(colors.FAIL +
              'Cannot find the Installer vars json file! No install/uninstall possible'
              + colors.ENDC)
        return True

    print(args.splunk_endpoint, args.splunk_token, args.splunk_index)


def replace_config(key, value, fileName):
    #TO DO

main()
