# frozen_string_literal: true

require 'fileutils'
require 'xcodeproj'
require_relative 'build_directory_helpers'
require_relative 'puts_helpers'
require_relative '../environment/environment'

# This module is used to create a DMG file and set up the appearance
module DMG
  def self.create(app_path)
    volume_name = Env.variables.app_display_name

    background_image_path = dmg_background_image_path
    volume_size = calculate_volume_size(app_path, background_image_path)
    dmg_path = create_blank_dmg(volume_size, volume_name)
    mount(dmg_path, volume_name)
    copy_app_and_set_symbolic_link(app_path, volume_name)
    copy_background_image(background_image_path, volume_name)
    customize_dmg_appearence(volume_name)
    unmount(volume_name)
    create_read_only_dmg(dmg_path)
  end

  def self.dmg_background_image_path
    background_image_path = Env.variables.dmg_background_image
    final_background_image_path = if background_image_path.start_with?('~')
                                    File.expand_path(background_image_path)
                                  elsif background_image_path.start_with?('/')
                                    background_image_path
                                  else
                                    File.expand_path(background_image_path, Env.variables.env_file_path)
                                  end

    raise 'DMG background image not found' unless !background_image_path || File.exist?(final_background_image_path)

    default_dmg_background_path = File.join(File.dirname(__dir__), 'resources', 'default-dmg-background.png')
    final_background_image_path ||= default_dmg_background_path
    final_background_image_path
  end

  def self.create_blank_dmg(volume_size, volume_name)
    puts_if_verbose 'Creating a blank DMG...'
    uuid = `uuidgen`.strip
    dmg_path = BuildDirectory.new_path("#{Env.variables.app_display_name}-#{uuid}.dmg")
    execute_command("hdiutil create -size #{volume_size}m -fs HFS+ -volname '#{volume_name}' -ov '#{dmg_path}'")
    dmg_path
  end

  def self.calculate_volume_size(app_path, background_image_path)
    app_size_kb = `du -sk "#{app_path}"`.split("\t").first.to_i
    background_size_kb = File.size(background_image_path) / 1024
    buffer_size_kb = 20 * 1024
    volume_size_kb = app_size_kb + background_size_kb + buffer_size_kb
    (volume_size_kb / 1024.0).ceil
  end

  def self.mount(dmg_path, volume_name)
    puts_if_verbose 'Mounting the DMG...'
    execute_command("hdiutil attach '#{dmg_path}' -mountpoint '/Volumes/#{volume_name}'")
  end

  def self.copy_app_and_set_symbolic_link(app_path, volume_name)
    puts_if_verbose 'Copying the app to the DMG and creating a symbolic link to the Applications folder...'
    FileUtils.cp_r(app_path, "/Volumes/#{volume_name}")
    execute_command("ln -s /Applications /Volumes/#{volume_name}/Applications")
  end

  def self.copy_background_image(background_image_path, volume_name)
    puts_if_verbose 'Copying the background image to the DMG...'
    FileUtils.mkdir_p("/Volumes/#{volume_name}/.background")

    background_image_extension = File.extname(background_image_path)
    FileUtils.cp(background_image_path,
                 "/Volumes/#{volume_name}/.background/dmg-background#{background_image_extension}")
  end

  def self.customize_dmg_appearence(volume_name)
    puts_if_verbose 'Customizing the appearance of the DMG...'

    app_x_position = Env.variables.dmg_window_width.to_i * 0.25
    applications_x_position = Env.variables.dmg_window_width.to_i * 0.75
    item_y_position = Env.variables.dmg_window_height.to_i / 2

    apple_script = dmg_appearence_apple_script(volume_name, app_x_position, applications_x_position, item_y_position)
    execute_command("osascript -e '#{apple_script}'")
  end

  def self.dmg_appearence_apple_script(volume_name, app_x_position, applications_x_position, item_y_position)
    window_width = Env.variables.dmg_window_width.to_i
    window_height = Env.variables.dmg_window_height.to_i
    <<-APPLESCRIPT
      tell application "Finder"
        tell disk "#{volume_name}"
          open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {0, 0, #{window_width}, #{window_height}}
            set arrangement of icon view options of container window to not arranged
            set icon size of icon view options of container window to #{Env.variables.dmg_icon_size}
            set background picture of icon view options of container window to file ".background:dmg-background.png"
            set position of item "#{Env.variables.app_display_name}.app" of container window to {#{app_x_position}, #{item_y_position}}
            set position of item "Applications" of container window to {#{applications_x_position}, #{item_y_position}}
          close
          open
            update without registering applications
            delay 5
        end tell
      end tell
    APPLESCRIPT
  end

  def self.unmount(volume_name)
    puts_if_verbose 'Unmounting the DMG...'
    command = "hdiutil detach '/Volumes/#{volume_name}'"
    begin
      execute_command(command)
    rescue StandardError
      puts_if_verbose 'Retrying unmount after a brief wait...'
      sleep 5
      execute_command(command)
    end
  end

  def self.create_read_only_dmg(dmg_path)
    puts_if_verbose 'Converting the DMG to read-only...'
    dmg_final_path = BuildDirectory.new_path("#{Env.variables.app_display_name}.dmg")
    execute_command("hdiutil convert '#{dmg_path}' -format UDZO -o '#{dmg_final_path}'")
    execute_command("rm -rf '#{dmg_path}'")
    dmg_final_path
  end
end
