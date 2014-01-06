#
# Author::  Seth Chisamore (<schisamo@opscode.com>)
# Author::  Lucas Hansen (<lucash@opscode.com>)
# Author::  Panagiotis Papadomitsos (<pj@ezgr.net>)
#
# Cookbook Name:: php
# Recipe:: package
#
# Copyright 2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
if platform?('windows')

  include_recipe 'iis::mod_cgi'

  install_dir = File.expand_path(node['php']['conf_dir']).gsub('/', '\\')
  windows_package node['php']['windows']['msi_name'] do
    source node['php']['windows']['msi_source']
    installer_type :msi

    options %W[
          /quiet
          INSTALLDIR="#{install_dir}"
          ADDLOCAL=#{node['php']['packages'].join(',')}
    ].join(' ')
  end

  # WARNING: This is not the out-of-the-box go-pear.phar. It's been modified to patch this bug:
  # http://pear.php.net/bugs/bug.php?id=16644
  cookbook_file "#{node['php']['conf_dir']}/PEAR/go-pear.phar" do
    source 'go-pear.phar'
  end

  template "#{node['php']['conf_dir']}/pear-options" do
    source 'pear-options.erb'
  end

  execute 'install-pear' do
    cwd node['php']['conf_dir']
    command 'go-pear.bat < pear-options'
    creates "#{node['php']['conf_dir']}/pear.bat"
  end

  ENV['PATH'] += ";#{install_dir}"
  windows_path install_dir

else
	#include_recipe 'yumrepo::atomic' if platform_family?('rhel')
	include_recipe 'apt' if platform_family?('debian')

	# Make sure the Apt cache is updated
	if platform_family?('debian')
		resources(:execute => 'apt-get update').run_action(:run)
	end

  #node['php']['packages'].each do |pkg|
  #  package pkg do
  #    action :install
  #  end
  #end

	# Run the package installation at compile time
	pkgs.each do |pkg|
		package pkg do
			action :nothing
		end.run_action(:install)
	end

	service 'php-fpm' if node['recipes'].include?('php::fpm') && platform_family?('rhel', 'fedora')

	include_recipe "php::ini"

	template "#{node['php']['cgi_conf_dir']}/php.ini" do
		source 'php.ini.erb'
		owner 'root'
		group 'root'
		mode 0644
		only_if { platform_family?('debian') }
	end

	directory node['php']['session_dir'] do
		owner 'root'
		group 'root'
		mode 01733
		recursive true
		action :create
	end

	directory node['php']['upload_dir'] do
		owner 'root'
		group 'root'
		mode 01777
		recursive true
		action :create
	end

	# Inherited from Debian packages, made universal, session cleanup script
	template '/usr/local/bin/php-maxlifetime' do
		source 'php-maxlifetime.sh.erb'
		owner 'root'
		group 'root'
		mode 00755
		only_if { platform_family?('rhel') }
	end

	template '/etc/cron.d/php5' do
		source 'php5.cron.erb'
		owner 'root'
		group 'root'
		variables({
			          :maxlifetime_script => platform_family?('rhel') ? '/usr/local/bin/php-maxlifetime' : '/usr/lib/php5/maxlifetime'
		          })
		mode 00644
	end

	if node['php']['tmpfs']
		total_mem = (node['memory']['total'].to_i / 1024) + (node['memory']['swap']['total'].to_i / 1024)
		if total_mem < node['php']['tmpfs_size'].to_i
			Chef::Log.info('You have specified a much bigger tmpfs session store than you can handle. Add more memory or swap or adjust the tmpfs size!')
		else
			[ node['php']['session_dir'], node['php']['upload_dir'] ].each do |dir|
				mount dir do
					device 'tmpfs'
					fstype 'tmpfs'
					options [ "size=#{node['php']['tmpfs_size']}", 'mode=1733', 'noatime', 'noexec', 'nosuid', 'nodev' ]
					dump 0
					pass 0
					action [:enable, :mount]
					supports [ :remount => true ]
				end
			end
		end
	end
end

