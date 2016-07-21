#
# Author:: Seth Chisamore <schisamo@getchef.com>
# Author:: Tim Smith <tsmith84@gmail.com>
# Cookbook Name:: nrpe
# Recipe:: _source_nrpe
#
# Copyright 2011-2013, Chef Software, Inc..
# Copyright 2012, Webtrends, Inc.
# Copyright 2013-2014, Limelight Networks, Inc.
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

remote_file "#{Chef::Config[:file_cache_path]}/nrpe-#{node['nrpe']['version']}.tar.gz" do
  source "#{node['nrpe']['url']}/nrpe-#{node['nrpe']['version']}.tar.gz"
  checksum node['nrpe']['checksum']
  action :create_if_missing
end

if node['init_package'] == 'systemd'
  execute 'nrpe-reload-systemd' do
    command '/bin/systemctl daemon-reload'
    action :nothing
  end

  # if we use systemd, make the nrpe.service a template to correct the user
  template '/usr/lib/systemd/system/nrpe.service' do
    source 'nrpe.service.erb'
    owner 'root'
    group 'root'
    mode '0644'
    notifies :run, 'execute[nrpe-reload-systemd]', :immediately
    notifies :restart, "service[#{node['nrpe']['service_name']}]"
    only_if  { node['init_package'] == 'systemd' }
    variables(
      nrpe: node['nrpe']
    )
  end
else
  template "/etc/init.d/#{node['nrpe']['service_name']}" do
    source 'nagios-nrpe-server.erb'
    owner 'root'
    group 'root'
    mode  '0754'
  end
end

directory node['nrpe']['conf_dir'] do
  owner 'root'
  group node['nrpe']['group']
  mode  '0750'
end

bash 'compile-nagios-nrpe' do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxvf nrpe-#{node['nrpe']['version']}.tar.gz
    cd nrpe-#{node['nrpe']['version']}
    ./configure --prefix=/usr \
                --sysconfdir=/etc \
                --localstatedir=/var \
                --libexecdir=#{node['nrpe']['plugin_dir']} \
                --libdir=#{node['nrpe']['home']} \
                --enable-command-args \
                --with-nagios-user=#{node['nrpe']['user']} \
                --with-nagios-group=#{node['nrpe']['group']} \
                --with-nrpe-user=#{node['nrpe']['user']} \
                --with-nrpe-group=#{node['nrpe']['group']} \
                --with-ssl=/usr/bin/openssl \
                --with-ssl-lib=#{node['nrpe']['ssl_lib_dir']} \
                --bindir=/usr/sbin/
    make -s
    make install
  EOH
  not_if 'which nrpe'
end
