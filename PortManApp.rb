['rubygems','sinatra','haml',"lib/portman"].each{|r|require r}

enable :sessions
set :password, 'bkrsta'

def authorized?; session[:authorized]; end
def authorize!;  redirect '/login' unless authorized?; end
def logout!; session[:authorized] = false ; end


get '/login' do
  @pwf = "Password: " +
  "<form method='post' name='flogin' action='/login'>" +
    "<input type='password' name='pass'>" +
  "</form>"
  haml :login
end

post '/login' do
  if params[:pass] == options.password
    session[:authorized] = true
    redirect '/'
  else
    session[:authorized] = false
    redirect '/login'
  end
end

get '/logout' do
  if authorized?
    session[:authorized] = false
    redirect "/"
  end
end

include Portman; class Hash
  def to_yaml(opts={})
    YAML::quick_emit(object_id,opts){|out|out.map(taguri,to_yaml_style){|map|sort.each{|k,v|map.add(k,v)}}}
end; end

def html_select(*args); option=Array.new(); args.each {|opt| option << "<option>#{opt}</option>\n"}; return option; end
def css; File.open("stylesheet.css").to_a.to_s; end

def ylo(a); YAML.load(File.open(a)); end
def frules; "rules.yml"; end
def fconfig; "config.yml"; end
def cmd; "/usr/bin/env ruby #{File.dirname(__FILE__)}/lib/portman.rb"; end
def btn_pri; {:href=>"/primjeni",:onclick=>"return confirm('Pokrenuti ?')"}; end
def btn_dod; {:href=>"/new"}; end

get '/' do redirect "/rules"; end
get '/rules' do
  if authorized?
    @router=ylo(fconfig)["ssh"]["host"];@rules=ylo(frules); haml :list
  else
    authorize!
  end
end
get '/primjeni' do
  t1=Time.now;@output=%x[#{cmd}];t2=Time.now;@time=t2-t1; haml :out
end
get '/del' do
  if authorized?
    @o = ""
    y = YAML.load(File.open(frules))
    r = y[params[:id].to_i].to_yaml
    if r == "--- {}\n\n" || r.match(/[a-zA-Z]/) == nil
      (@o += "Rule #{params[:id]} je prazan!"; haml :del; return)
    else
      y.delete(params[:id].to_i)
      @o += "Removed: #{r}\n"
      File.open(frules, "w"){|file| file.puts(YAML.dump(y)) }
      @o += "Rule #{params[:id]} deleted from rules.yml!\n"
      #TODO: Portman::Cof(frules).delete(params[:id])
      haml :del
    end
  else
    authorize!
  end
end

get '/new' do
  if authorized?
    haml :new
  else
    authorize!
  end
end

post '/new' do
  if authorized?
    rule_id = params[:id].to_i
    params.delete "id"

    if params[:port_na] == params[:port_sa]
      params["port"] = params[:port_na]
      params.delete "port_na"
      params.delete "port_sa"
    end
    var = {rule_id => params}

    File.open(frules, 'a') {|f| f.write("\n"+var.to_yaml.gsub("--- \n","").chop) }

    @o = "<p>Rule #{rule_id} added to config file!</p>\n"+"Rule:<pre>#{var.to_yaml}</pre>"
    haml :new_p
  else
    authorize!
  end
end

get '/src' do
  x = File.open(__FILE__).to_a.to_s
  "<pre>#{x}</pre>"
end

use_in_file_templates!

__END__

# @@ layoutO
# %html
#   %head
#     %title Vyatta PortMan
#   %body
#     #container
#       - if authorized?
#         %p
#           %a{href="/logout"} Logout
#       = yield

@@ layout
!!! Strict
%html
  %head
    %title Vyatta PortMan
    %meta{"http-equiv"=>"Content-Type", :content=>"text/html; charset=utf-8"}/
    = "<style type='text/css'>#{css}</style>"

  %body
    #container
      - if authorized?
        %p.logout
          %a(href="/logout") Logout
      %br
      = yield
      %br

@@ login
%center
  %br
  %br
  = @pwf
  %script
    = "document.flogin.pass.focus();"
  %br
  %br

@@ list
%h2= "NAT Rules (za #{@router})"
#list
  - @rules.each do |rule|
    %h3.title
      - rule_id = rule[0]
      %a{:href=>"/del?id=#{rule_id}"} [DEL]
      = "#{rule_id}: #{if rule[1]["desc"]!=""; rule[1]["desc"] else; "<i>untitled</i>" end}"
    %p= "0.0.0.0:#{rule[1]["port_sa"]||rule[1]["port"]} -> #{rule[1]["host"]}:#{rule[1]["port_na"]||rule[1]["port"]}"
  %font{"size"=>"+2"}
    %a{btn_pri} Primjeni
    |
    %a{btn_dod} Dodaj

@@ out
#output
  %b
    %font{"size"=>"+1"}
      %pre= cmd
  - if @output!=""
    %pre(size=14)= "#{@output}\n\n[Time elapsed: #{@time}]"
  %h3= if @output != ""; "Kraj!" else; "Prazan output!"; end
  %p
    %a(href="/") [ROOT]

@@ del
%pre
  = @o
%p
  %a(href="/") [ROOT]

@@ new
%form(name="rule" action="/new" method="post")
  %table
    %tr
      %td
        Rule ID:
      %td
        %input(type="text" name="id" size=5)
    %tr
      %td(width="70px") Port sa:
      %td
        %input(type="text" name="port_sa" size=4)
    %tr
      %td Host na:
      %td
        %input(type="text" name="host" size=15)
        != ":"
        %input(type="text" name="port_na" size=4)
    %tr
      %td Proto:
      %td
        %select(name="proto")
          != html_select("tcp","udp")
    %tr
      %td
        Desc.:
      %td
        %input(type="text" name="desc" value="description")
  %p
    %input(type="submit" value="Dodaj")
%p
  %a(href="/") [ROOT]

@@ new_p

%pre
  = @o

%p
  %a(href="/") [ROOT]
