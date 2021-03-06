###################################
#
# EVM Automate Method: HPOM_Storage_Alert
#
# This method is used to send HPOM Alerts based on Datastore
#
###################################
begin
  @method = 'HPOM_Storage_Alert'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  ###################################
  #
  # Method: buildDetails
  #
  # Notes: Build email subject and body which map to opcmsg_msg_grp and opcmsg_msg_text
  # 
  # Returns: options Hash
  #
  ###################################
  def buildDetails(storage)

    # Build options Hash
    options = {}

    options[:object] = "Datastore - #{storage.name}"

    # Set alert to alert description
    options[:alert] = $evm.root['miq_alert_description']

    # Get Appliance name from model unless specified below
    appliance = nil
    #appliance ||= $evm.object['appliance']
    appliance ||= $evm.root['miq_server'].ipaddress

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Build Email Subject
    subject = "#{options[:alert]} | Datastore: [#{storage.name}]"
    options[:subject] = subject

    # Build Email Body
    body = "Attention, "
    body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
    body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
    body += "<br>Alert: #{options[:alert]}"
    body += "<br><br>"

    body += "<br>Storage <b>#{storage.name}</b> Properties:"
    body += "<br>Storage URL: <a href='https://#{appliance}/Storage/show/#{storage.id}'>https://#{appliance}/Storage/show/#{storage.id}</a>"
    body += "<br>Type: #{storage.store_type}"
    body += "<br>Free Space: #{storage.free_space.to_i / (1024**3)} GB (#{storage.v_free_space_percent_of_total}%)"
    body += "<br>Used Space: #{storage.v_used_space.to_i / (1024**3)} GB (#{storage.v_used_space_percent_of_total}%)"
    body += "<br>Total Space: #{storage.total_space.to_i / (1024**3)} GB"
    body += "<br><br>"

    body += "<br>Information for Registered VMs:"
    body += "<br>Used + Uncommitted Space: #{storage.v_total_provisioned.to_i / (1024**3)} GB (#{storage.v_provisioned_percent_of_total}%)"
    body += "<br><br>"

    body += "<br>Content:"
    body += "<br>VM Provisioned Disk Files: #{storage.disk_size.to_i / (1024**3)} GB (#{storage.v_disk_percent_of_used}%)"
    body += "<br>VM Snapshot Files: #{storage.snapshot_size.to_i / (1024**3)} GB (#{storage.v_snapshot_percent_of_used}%)"
    body += "<br>VM Memory Files: #{storage.v_total_memory_size.to_i / (1024**3)} GB (#{storage.v_memory_percent_of_used}%)"
    body += "<br><br>"

    body += "<br>Relationships:"
    body += "<br>Number of Hosts attached: #{storage.v_total_hosts}"
    body += "<br>Total Number of VMs: #{storage.v_total_vms}"
    body += "<br><br>"

    body += "<br>Datastore Tags:"
    body += "<br>#{storage.tags.inspect}"
    body += "<br><br>"

    body += "<br>Regards,"
    body += "<br>#{signature}"
    options[:body] = body

    # Return options Hash with subject, body, alert
    return options
  end


  ###################################
  #
  # Method: boolean
  # Returns: true/false
  #
  ###################################
  def boolean(string)
    return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

    # Return false if string does not match any of the above
    $evm.log("info","#{@method} - Invalid boolean string:<#{string}> detected. Returning false") if @debug
    return false
  end


  ###################################
  #
  # Method: emailStorageAlert
  #
  # Build Alert email
  #
  ###################################
  def emailAlert(options )
    # Get to_email_address from model unless specified below
    to = nil
    to  ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get subject from options Hash
    subject = options[:subject]

    # Get body from options Hash
    body = options[:body]

    $evm.log("info", "#{@method} - Sending email To:<#{to}> From:<#{from}> subject:<#{subject}>") if @debug
    $evm.execute(:send_email, to, from, subject, body)
  end


  ###################################
  #
  # Method: call_opcmsg
  #
  # Notes: Run opcmsg to send an event to HP Operations Manager
  #
  ###################################
  def call_opcmsg(options)
    opcmsg_path = "/opt/OV/bin/opcmsg"
    raise "#{@method} - File '#{opcmsg_path}' does not exist" unless File.exist?(opcmsg_path)
    $evm.log("info","#{@method} - Found opcmsg_path:<#{opcmsg_path}>") if @debug

    cmd  = "#{opcmsg_path}"
    cmd += " application=\"#{$evm.object['opcmsg_application']}\""
    cmd += " object=\"#{options[:object]}\""
    cmd += " msg_text=\"#{options[:body]}\""
    cmd += " severity=\"#{$evm.object['opcmsg_severity']}\""
    cmd += " msg_grp=\"#{options[:alert]}\""

    $evm.log("info","#{@method} - Calling:<#{cmd}>") if @debug
    require 'open4'
    pid = nil
    stderr = nil
    results = Open4.popen4(cmd) do |pid, stdin, stdout, stderr|
      stderr.each_line { |msg| $evm.log("error","#{@method} - Method STDERR:<#{msg.strip}>") }
      stdout.each_line { |msg| $evm.log("info","#{@method} - Method STDOUT:<#{msg.strip}>") }
    end
    $evm.log("info","#{@method} - Inspecting Results:<#{results.inspect}>") if @debug
  end


  storage = $evm.root['storage']

  unless storage.nil?
    # If email is set to true in the model
    options = buildDetails(storage)

    # Get email from model
    email = $evm.object['email']

    if boolean(email)
      emailAlert(options)
    end

    call_opcmsg(options)
  end


  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
