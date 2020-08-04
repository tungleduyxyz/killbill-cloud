# frozen_string_literal: true

require 'spec_helper'

describe KPM::Inspector do
  before(:each) do
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    tmp_bundles_dir = Dir.mktmpdir
    @bundles_dir = Pathname.new(tmp_bundles_dir).expand_path
    @plugins_dir = @bundles_dir.join('plugins')

    FileUtils.mkdir_p(@plugins_dir)

    @ruby_plugins_dir = @plugins_dir.join('ruby')
    FileUtils.mkdir_p(@ruby_plugins_dir)

    @java_plugins_dir = @plugins_dir.join('java')
    FileUtils.mkdir_p(@java_plugins_dir)

    @manager = KPM::PluginsManager.new(@plugins_dir, @logger)

    @sha1_file = @bundles_dir.join('sha1.yml')
    @sha1_checker = KPM::Sha1Checker.from_file(@sha1_file)
  end

  it 'should parse a correctly setup env' do
    add_plugin('foo', 'plugin_foo', ['1.2.3', '2.0.0', '2.0.1'], 'ruby', 'com.foo', 'foo', 'tar.gz', nil, %w[12345 23456 34567], '2.0.1', ['1.2.3'])
    add_plugin('bar', 'plugin_bar', ['1.0.0'], 'java', 'com.bar', 'bar', 'jar', nil, ['98765'], nil, [])

    inspector = KPM::Inspector.new
    all_plugins = inspector.inspect(@bundles_dir)
    expect(all_plugins.size).to eq 2

    expect(all_plugins['plugin_bar'][:plugin_key]).to eq 'bar'
    expect(all_plugins['plugin_bar'][:plugin_path]).to eq @java_plugins_dir.join('plugin_bar').to_s
    expect(all_plugins['plugin_bar'][:versions].size).to eq 1
    expect(all_plugins['plugin_bar'][:versions][0][:version]).to eq '1.0.0'
    expect(all_plugins['plugin_bar'][:versions][0][:is_default]).to eq false
    expect(all_plugins['plugin_bar'][:versions][0][:is_disabled]).to eq false
    expect(all_plugins['plugin_bar'][:versions][0][:sha1]).to eq '98765'

    expect(all_plugins['plugin_foo'][:plugin_key]).to eq 'foo'
    expect(all_plugins['plugin_foo'][:plugin_path]).to eq @ruby_plugins_dir.join('plugin_foo').to_s
    expect(all_plugins['plugin_foo'][:versions].size).to eq 3

    expect(all_plugins['plugin_foo'][:versions][0][:version]).to eq '1.2.3'
    expect(all_plugins['plugin_foo'][:versions][0][:is_default]).to eq false
    expect(all_plugins['plugin_foo'][:versions][0][:is_disabled]).to eq true
    expect(all_plugins['plugin_foo'][:versions][0][:sha1]).to eq '12345'

    expect(all_plugins['plugin_foo'][:versions][1][:version]).to eq '2.0.0'
    expect(all_plugins['plugin_foo'][:versions][1][:is_default]).to eq false
    expect(all_plugins['plugin_foo'][:versions][1][:is_disabled]).to eq false
    expect(all_plugins['plugin_foo'][:versions][1][:sha1]).to eq '23456'

    expect(all_plugins['plugin_foo'][:versions][2][:version]).to eq '2.0.1'
    expect(all_plugins['plugin_foo'][:versions][2][:is_default]).to eq true
    expect(all_plugins['plugin_foo'][:versions][2][:is_disabled]).to eq false
    expect(all_plugins['plugin_foo'][:versions][2][:sha1]).to eq '34567'
  end

  private

  def add_plugin(plugin_key, plugin_name, versions, language, group_id, artifact_id, packaging, classifier, sha1, active_version, disabled_versions)
    plugin_dir = language == 'ruby' ? @ruby_plugins_dir.join(plugin_name) : @java_plugins_dir.join(plugin_name)

    versions.each_with_index do |v, idx|
      coordinate_map = { group_id: group_id, artifact_id: artifact_id, version: v, packaging: packaging, classifier: classifier }
      coordinates = KPM::Coordinates.build_coordinates(coordinate_map)

      @manager.add_plugin_identifier_key(plugin_key, plugin_name, language, coordinate_map)
      @sha1_checker.add_or_modify_entry!(coordinates, sha1[idx])

      plugin_dir_version = plugin_dir.join(v)

      FileUtils.mkdir_p(plugin_dir_version)

      # Create some entry to look real
      some_file = language == 'ruby' ? 'ROOT' : "#{plugin_name}.jar"
      FileUtils.touch(plugin_dir_version.join(some_file))
    end

    @manager.set_active(plugin_dir, active_version) if active_version

    disabled_versions.each do |v|
      @manager.uninstall(plugin_dir, v)
    end
  end
end
