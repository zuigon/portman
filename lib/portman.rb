#!/usr/bin/ruby

module Portman
  require "rubygems"
  require "open-uri"
  require 'yaml'
  require "net/ssh"
  require 'needle'

  class Host
    def initialize(host=nil, user=nil, passw=nil)
      @data = {}
      if host && user && passw
        @data[:host]  = host
        @data[:user]  = user
        @data[:passw] = passw
      elsif host.class == Hash
        @data[:host]  = host["host"]
        @data[:user]  = host["user"]
        @data[:passw] = host["passw"]
      else
        fail "> No config data! ..."
      end
    end

    def execO(&block)
      Net::SSH.start( @data[:host], @data[:user], :password => @data[:passw] ) do |ssh|
        # cmd = yield
        output = ""
        yield.each do |cmd|
          puts " >> #{cmd}"
          output << " << "+ssh.exec!("_vyatta_op_run "+cmd)
        end
        return output
        ssh.loop
      end
    end

    def execLAST(&block)
      puts
      puts ".. SSH connect"
      Net::SSH.start( @data[:host], @data[:user], :password => @data[:passw] ) do |ssh|
        # cmd = yield
        puts "EXEC():"
        output = ""
        ssh.exec!("_vyatta_op_run "+"/bin/bash")
        puts " >> configure"
        puts ssh.exec!("_vyatta_op_run "+"configure")
        yield.each do |rule|
          rule.each do |cmd|
            puts " >> #{cmd}"
            # output << " << "+ssh.exec!("_vyatta_op_run "+cmd)+"\n"
            ssh.exec!("_vyatta_op_run "+cmd) do |channel, stream, data|
              if stream == :stdout
                puts " << "+data
                output << data
              elsif stream == :stderr
                puts "E! << "+data
              end
            end
          end
        end
        puts " ?? >> Commit? [commit]"
        # output << " << "+ssh.exec!("_vyatta_op_run "+"commit")+"\n"
        output << " << "+ssh.exec!("_vyatta_op_run "+"exit discard")+"\n" # EXIT!

        puts " >> exit"
        output << " << "+ssh.exec!("_vyatta_op_run "+"exit")+"\n"
        return output
        # ssh.loop
      end
    end

    def exec(rules)
      puts
      puts ".. SSH connect"
      Net::SSH.start( @data[:host], @data[:user], :password => @data[:passw] ) do |ssh|

        puts "EXEC():"

        open_ch(ssh, 'echo "Vyatta!!"')

        # open_ch(ssh, "_vyatta_op_run "+"/bin/bash")
        puts " >> configure"
        open_ch(ssh, "_vyatta_op_run "+"configure")

        rules.each do |rule|
          rule.each do |cmd|
            puts " >> #{cmd}"
            # output << " << "+ssh.exec!("_vyatta_op_run "+cmd)+"\n"
            # out = shell.send_command("_vyatta_op_run "+cmd)
            open_ch(ssh, "_vyatta_op_run "+cmd)
          end
        end

        puts " ?? >> Commit? [commit]" # output << " << "+ssh.exec!("_vyatta_op_run "+"commit")+"\n" # output << " << "
        open_ch(ssh, "_vyatta_op_run "+"exit discard") # "\n" # EXIT!
        puts " >> exit" # output << " << "
        open_ch(ssh, "_vyatta_op_run "+"exit") # "\n" # p shell.exit
      end
    end

    def load_rules(*args)
      @nat_rules = args[0].to_a
      puts "Loaded #{@nat_rules.count} rules"
    end

    def gen_rules_cmds
      if @nat_rules
        out = []; c=0
        @nat_rules.each do |rule|
          rule_o = "set service nat rule #{rule[0]}\n"
          rule_o << "edit service nat rule #{rule[0]}\n"
          rule_o << "set description '\#PortMan\# #{rule[1]['desc']}'\n"
          rule_o << "set type destination\n"
          # rule_o << "set translation-type static\n"
          rule_o << "set inbound-interface pppoe1\n"
          rule_o << "set source address 0.0.0.0/0\n"
          rule_o << "set protocol #{rule[1]['proto'] or 'tcp'}\n"
          rule_o << "set destination address 0.0.0.0/0\n"
          rule_o << "set destination port #{rule[1]['port_sa']||rule[1]['port']}\n"
          rule_o << "set inside-address address #{rule[1]['host']}\n"
          rule_o << "set inside-address port #{rule[1]['port_na']||rule[1]['port']}\n"
          rule_o << "exit"
          out << rule_o.split("\n")
          c+=1
        end
        puts "Generated #{c} rules"
        return out
      else
        fail "Rules not loaded!"
      end
    end

    def exec_cmdline(cmd); system "echo \"#{cmd}\" | ssh -tt -l #{@data[:user]} #{@data[:host]}"; end

    def open_ch ssh, cmd
      channel = ssh.open_channel do |ch|
        ch.exec cmd do |ch, success|
          raise "could not execute command" unless success
          ch.on_data { |c, data| puts " << #{data}" } # "on_data" is called when the process writes something to stdout
          ch.on_extended_data { |c, type, data| puts "!<< #{data}" } # "on_extended_data" is called when the process writes something to stderr
          ch.on_close { puts "done!" }
        end
      end
      channel.wait
    end

  end

  class CmdFormat
    def initialize(args); @rules = args; end
    def format_za_exec; o = ""; @rules.each { |rule| o+=rule.join("; ") + "\n" }; o; end
    def full_cmd; "configure\n"+format_za_exec+"commit\necho Commited\nexit\nexit\n"; end
  end

end

if __FILE__ == $0
  include Portman
  @config = YAML.load(File.open("config.yml"))["ssh"]
  h2 = Host.new(@config) # ILI: h = Host.new( "192.168.1.1","root","...." )
  h2.load_rules(YAML.load(File.open("rules.yml")))
  comm = CmdFormat.new(h2.gen_rules_cmds).full_cmd
  puts h2.exec_cmdline(comm)
end
