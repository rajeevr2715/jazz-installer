default['jenkins']['home'] = '/var/lib/jenkins'
default['chef_root'] = '/tmp/jazz-chef'
default['script_root'] = "#{node['chef_root']}/chefscripts"
default['jenkins']['clientjar'] = "#{node['chef_root']}/jenkins-cli.jar"
default['authfile'] = "#{node['chef_root']}/authfile"
default['jenkinselb'] = 'jazz-jenkinselb-.us-east-1.elb.amazonaws.com'

#This is the universal invocation that all scripts will use/append to.
default['jenkins']['clicommand'] = "'java -jar #{node['jenkins']['clientjar']} -s http://#{node['jenkinselb']}/ -auth @#{node['authfile']}'"

default['region'] = 'us-east-1'
default['git_plugin_branch'] = 'master'
default['git_content_repo'] = 'https://github.com/tmobile/jazz-content/raw'
default['git_content_plugins'] = 'jenkins/staticplugins/plugins.tar'
default['git_content_xmls'] = 'jenkins/files/xmls.tar'

#Maven cookbook property
default['maven']['version'] = '3.5.2'
default['maven']['setup_bin'] = true

#Node cookbook property
default['nodejs']['version'] = '8'
default['nodejs']['install_method'] = 'package'
#This monkeypatch is necessary because the node cookbook brokenly defaults to a 6.x sources.list otherwise
case node['platform_family']
when 'debian'
  override['nodejs']['repo'] = 'https://deb.nodesource.com/node_8.x'
when 'rhel', 'amazon'
  default['nodejs']['repo'] = "https://rpm.nodesource.com/pub_8.x/el/$releasever/$basearch"
end
