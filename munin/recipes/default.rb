#
# Cookbook Name:: munin
# Recipe:: default
#
# Copyright 2012, Hiroaki Nakamura
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

login = node.munin.web_interface_login
password = node.munin.web_interface_password

include_recipe "nginx"

# We must start the munin-node service before running munin-cron to create
# rrd files.
include_recipe "munin-node"

yum_package "munin"
yum_package "munin-cgi"
yum_package "httpd-tools"

bash "create_munin-htpasswd" do
  code <<-EOH
    htpasswd -b -c /etc/munin/munin-htpasswd "#{login}" "#{password}" 
  EOH
  # /etc/munin/munin-htpassword is contained in munin-cgi yum package.
  #creates "/etc/munin/munin-htpasswd"
end

directory "/var/lib/munin/cgi-tmp" do
  owner "munin"
  group "munin"
  mode "0777"
end

directory "/var/lib/munin/cgi-tmp/munin-cgi-graph" do
  owner "nginx"
  group "nginx"
  mode "0777"
end

template "/etc/munin/munin.conf" do
  source "munin.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :graph_data_size => node[:munin][:graph_data_size],
    :host_tree_configs => node[:munin][:host_tree_configs]
  )
end

directory "/var/log/munin" do
  # munin-fcgi-html and munin-fcgi-graph writes logs here by nginx user.
  # munin-cron write logs here by munin user.
  owner "nginx"
  group "munin"
  mode "0777"
end

bash "munin-create-rrdtool-files" do
  # Note: The munin-cron fails at the first time. It successfully creates rrd
  # files at the second time.
  code <<-EOH
    /sbin/service munin-node start
    su - munin --shell=/bin/bash /usr/bin/munin-cron || \
    su - munin --shell=/bin/bash /usr/bin/munin-cron
  EOH
  creates "/var/lib/munin/htmlconf.storable"
end

template "/etc/cron.d/munin" do
  source "munin.cron.erb"
  owner "root"
  group "root"
  mode "0644"
end

cookbook_file "#{node.munin.nginx_munin_conf_dir}/munin.conf" do
  source "nginx.munin.conf"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]'
end

cookbook_file "/etc/init.d/munin-fcgi-html" do
  source "munin-fcgi-html"
  owner "root"
  group "root"
  mode "0755"
end
service "munin-fcgi-html" do
  action [:enable, :start]
end

cookbook_file "/etc/init.d/munin-fcgi-graph" do
  source "munin-fcgi-graph"
  owner "root"
  group "root"
  mode "0755"
end
service "munin-fcgi-graph" do
  action [:enable, :start]
end
