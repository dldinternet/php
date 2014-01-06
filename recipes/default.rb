#
# Author::  Joshua Timberman (<joshua@opscode.com>)
# Author::  Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: php
# Recipe:: default
#
# Copyright 2009-2011, Opscode, Inc.
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

include_recipe 'php::package'

# update the main channels
php_pear_channel 'pear.php.net' do
  action :update
  notifies :run, "bash[pear-channel-update]", :immediately
end

bash "pear-channel-update" do
  code "pear channel-update pear.php.net ; touch /root/pear.php.net.channel"
  action :run
  not_if { File.exists?("/root/pear.php.net.channel") }
end

package "gcc"
package "make"

php_pear_channel 'pecl.php.net' do
  action :update
  notifies :run, "bash[pecl-channel-update]", :immediately
end

bash "pecl-channel-update" do
  code "pecl channel-update pecl.php.net ; touch /root/pecl.php.net.channel"
  action :run
  not_if { File.exists?("/root/pecl.php.net.channel") }
end

include_recipe "php::ini"
