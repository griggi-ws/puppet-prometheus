# @summary This module manages prometheus RDS exporter by qonto
# @see https://github.com/qonto/prometheus-rds-exporter
# @param arch
#  Architecture (amd64 or i386)
# @param bin_dir
#  Directory where binaries are located
# @param config_file
#  Absolute path to configuration file (blackbox module definitions)
# @param manage_config
# Whether or not to create a config file
# @param config_content
#  Hash of the desired configuration
# @param download_extension
#  Extension for the release binary archive
# @param download_url
#  Complete URL corresponding to the where the release binary archive can be downloaded
# @param download_url_base
#  Base URL for the binary archive
# @param extra_groups
#  Extra groups to add the binary user to
# @param extra_options
#  Extra options added to the startup command
# @param group
#  Group under which the binary is running
# @param init_style
#  Service startup scripts style (e.g. rc, upstart or systemd)
# @param install_method
#  Installation method: url or package (only url is supported currently)
# @param manage_group
#  Whether to create a group for or rely on external code for that
# @param manage_service
#  Should puppet manage the service? (default true)
# @param manage_user
#  Whether to create user or rely on external code for that
#  Structured, array of blackbox module definitions for different probe types
# @param export_scrape_job
#  Whether to export a scrape job for this service
# @param scrape_host
#  Hostname or IP address to scrape
# @param scrape_port
#  Host port to scrape
# @param scrape_job_name
#  Name of the scrape job to export, if export_scrape_job is true
# @param scrape_job_labels
#  Labels to add to the scrape job, if export_scrape_job is true
# @param os
#  Operating system (linux is the only one supported)
# @param package_ensure
#  If package, then use this for package ensure default 'latest'
# @param package_name
#  The binary package name - not available yet
# @param restart_on_change
#  Should puppet restart the service on configuration change? (default true)
# @param service_enable
#  Whether to enable the service from puppet (default true)
# @param service_ensure
#  State ensured for the service (default 'running')
# @param service_name
#  Name of the node exporter service (default 'blackbox_exporter')
# @param user
#  User which runs the service
# @param version
#  The binary release version
# @param config_mode
#  The permissions of the configuration files
# @param env_vars
#  hash with custom environment variables thats passed to the exporter via init script / unit file
# @param env_file_path
#  The path to the file with the environmetn variable that is read from the init script/systemd unit
# @param proxy_server
#  Optional proxy server, with port number if needed. ie: https://example.com:8080
# @param proxy_type
#  Optional proxy server type (none|http|https|ftp)
# @param web_config_file
#  Path of file where the web-config will be saved to
# @param web_config_content
#  Unless empty the content of the web-config yaml which will handed over as option to the exporter
class prometheus::rds_exporter (
  String $download_extension = 'tar.gz',
  Prometheus::Uri $download_url_base = 'https://github.com/qonto/prometheus-rds-exporter/releases',
  Array[String] $extra_groups = [],
  String[1] $group = 'rds-exporter',
  String[1] $package_ensure = 'latest',
  String[1] $package_name = 'prometheus-rds-exporter',
  String[1] $service_name = 'rds_exporter',
  String[1] $user = 'rds-exporter',
  # renovate: depName=qonto/prometheus-rds-exporter
  String[1] $version = '0.10.0',
  Boolean $manage_config                                     = false,
  Hash $config_content                                       = {},
  Stdlib::Absolutepath $config_file                          = '/etc/rds-exporter.yaml',
  Boolean $restart_on_change                                 = true,
  Boolean $service_enable                                    = true,
  Stdlib::Ensure::Service $service_ensure                    = 'running',
  Prometheus::Initstyle $init_style                          = $prometheus::init_style,
  Prometheus::Install $install_method                        = $prometheus::install_method,
  Boolean $manage_group                                      = true,
  Boolean $manage_service                                    = true,
  Boolean $manage_user                                       = true,
  String[1] $os                                              = $facts['kernel'],
  Optional[String[1]] $extra_options                         = undef,
  Optional[Prometheus::Uri] $download_url                    = undef,
  String[1] $config_mode                                     = $prometheus::config_mode,
  String[1] $arch                                            = $facts['os']['hardware'],
  Stdlib::Absolutepath $bin_dir                              = $prometheus::bin_dir,
  Boolean $export_scrape_job                                 = false,
  Optional[Stdlib::Host] $scrape_host                        = undef,
  Stdlib::Port $scrape_port                                  = 9043,
  String[1] $scrape_job_name                                 = 'rds',
  Optional[Hash] $scrape_job_labels                          = undef,
  Hash[String[1], Scalar] $env_vars                          = {},
  Stdlib::Absolutepath $env_file_path                        = $prometheus::env_file_path,
  Optional[String[1]] $proxy_server                          = undef,
  Optional[Enum['none', 'http', 'https', 'ftp']] $proxy_type = undef,
  Stdlib::Absolutepath $web_config_file                      = '/etc/rds_exporter_web-config.yml',
  Prometheus::Web_config $web_config_content                 = {},
) inherits prometheus {
  $real_download_url = pick($download_url,"${download_url_base}/download/${version}/${package_name}_${os}_${arch}.${download_extension}")
  $notify_service = $restart_on_change ? {
    true    => Service[$service_name],
    default => undef,
  }

  $extract_path = "/opt/${service_name}-${version}.${downcase($os)}-${arch}"

  file { $extract_path:
    ensure => directory,
    owner  => 'root',
    group  => 0, # 0 instead of root because OS X uses "wheel".
    mode   => '0755',
    before => Prometheus::Daemon[$service_name],
  }

  if $manage_config {
    file { $config_file:
      ensure  => file,
      mode    => $config_mode,
      owner   => 'root',
      group   => $group,
      content => $config_content.stdlib::to_yaml,
      notify  => $notify_service,
    }
  }
  $_web_config_ensure = $web_config_content.empty ? {
    true    => absent,
    default => file,
  }

  file { $web_config_file:
    ensure  => $_web_config_ensure,
    owner   => $user,
    group   => $group,
    mode    => '0640',
    content => $web_config_content.stdlib::to_yaml,
    notify  => $notify_service,
  }

  $_web_config = if $web_config_content.empty {
    ''
  } else {
    "--web.config.file=${$web_config_file}"
  }
  $_config = if $manage_config {
    "--config.file=${config_file}"
  } else {
    ''
  }
  $options = [
    $_config,
    $extra_options,
    $_web_config,
  ].filter |$x| { !$x.empty }.join(' ')

  prometheus::daemon { $service_name:
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    archive_bin_path   => "${extract_path}/${package_name}",
    extract_path       => $extract_path,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
    export_scrape_job  => $export_scrape_job,
    scrape_host        => $scrape_host,
    scrape_port        => $scrape_port,
    scrape_job_name    => $scrape_job_name,
    scrape_job_labels  => $scrape_job_labels,
    env_vars           => $env_vars,
    env_file_path      => $env_file_path,
    proxy_server       => $proxy_server,
    proxy_type         => $proxy_type,
  }
}
