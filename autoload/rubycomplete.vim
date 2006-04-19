" Vim completion script
" Language:				Ruby
" Maintainer:			Mark Guzman <segfault@hasno.info>
" Info:					$Id: rubycomplete.vim,v 1.6 2006/04/19 18:31:34 segy Exp $
" URL:					http://vim-ruby.rubyforge.org
" Anon CVS:				See above site
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" ----------------------------------------------------------------------------
"
" Ruby IRB/Complete author: Keiju ISHITSUKA(keiju@ishitsuka.com)
" ----------------------------------------------------------------------------

if !has('ruby')
    echohl ErrorMsg
    echo "Error: Required vim compiled with +ruby"
    echohl None
    finish
endif

if version < 700
    echohl ErrorMsg
    echo "Error: Required vim >= 7.0"
    echohl None
    finish
endif


function! GetBufferRubyModule(name)
    let [snum,enum] = GetBufferRubyEntity(a:name, "module")
    return snum . '..' . enum
endfunction

function! GetBufferRubyClass(name)
    let [snum,enum] = GetBufferRubyEntity(a:name, "class")
    return snum . '..' . enum
endfunction

function! GetBufferRubySingletonMethods(name)
endfunction

function! GetBufferRubyEntity( name, type )
    let stopline = 1
    "let crex = '^\s*' . a:type . '\s*' . a:name . '\s*\(<\s*.*\)\?\n*\(\(\s*.*\s*\n*\)*\|\(\s*def\s*.*\n.*\s*\n\s*end\s*\n*\)*\)*\n*\s*end\s*\n*$' 
    let crex = '^\s*' . a:type . '\s*' . a:name . '\s*\(<\s*.*\s*\)\?\n*\(\(\s\|#\).*\n*\)*\n*\s*end$'
    let [lnum,lcol] = searchpos( crex, 'nbw')
    if lnum == 0 && lcol == 0
        return [0,0]
    endif
    let [enum,ecol] = searchpos( crex, 'nebw')
    if lnum > enum
        echo "HERE UGH: " . lnum
        let realdef = getline( lnum )
        echo "PAST GETLINE"
        let crexb = '^' . realdef . '\n*\(\(\s\|#\).*\n*\)*\n*\s*end$'
        echo "RE: " . crexb
        let [enum,ecol] = searchpos( crexb, 'necw' )
        echo "enumb: " . enum
    endif
    " we found a the class def
    return [lnum,enum]
endfunction

function! IsInClassDef()
    let [snum,enum] = GetBufferRubyEntity( '.*', "class" )
    let ret = 'nil'
    let pos = line('.')

    echo "pos: " . pos
    echo "snum: " . snum
    echo "enum: " . enum
    if snum < pos && pos < enum 
        print "LIVE"
        let ret = snum . '..' . enum
    endif

    return ret
endfunction

function! GetRubyVarType(v)
	let stopline = 1
	let vtp = ''
	let pos = getpos('.')
	let [lnum,lcol] = searchpos('^\s*#\s*@var\s*'.a:v.'\>\s\+[^ \t]\+\s*$','nb',stopline)
	if lnum != 0 && lcol != 0
		call setpos('.',pos)
		let str = getline(lnum)
		let vtp = substitute(str,'^\s*#\s*@var\s*'.a:v.'\>\s\+\([^ \t]\+\)\s*$','\1','')
		return vtp
	endif
	call setpos('.',pos)
    let [lnum,lcol] = searchpos(''.a:v.'\>\s*[+\-*/]*=\s*\([^ \t]\+.\(now\|new\|open\|get_instance\)\>\|[\[{"''/]\|%r{\)','nb',stopline)
	if lnum != 0 && lcol != 0
        let str = matchstr(getline(lnum),'=\s*\([^ \t]\+.\(now\|new\|open\|get_instance\)\>\|[\[{"''/]\|%r{\)',lcol)
		let str = substitute(str,'^=\s*','','')
		call setpos('.',pos)
		if str == '"' || str == ''''
			return 'String'
		elseif str == '['
			return 'Array'
		elseif str == '{'
			return 'Hash'
        elseif str == '/' || str == '%r{'
            return 'Regexp'
		elseif strlen(str) > 4
            let l = stridx(str,'.')
			return str[0:l-1]
		end
		return ''
	endif
	call setpos('.',pos)
    return ''
endfunction

function! rubycomplete#Complete(findstart, base)
     "findstart = 1 when we need to get the text length
    if a:findstart
        let line = getline('.')
        let idx = col('.')
        while idx > 0
            let idx -= 1
            let c = line[idx-1]
            if c =~ '\w'
                continue
            elseif ! c =~ '\.'
                idx = -1
                break
            else
                break
            endif
        endwhile

        return idx
    "findstart = 0 when we need to return the list of completions
    else
        execute "ruby get_completions('" . a:base . "')"
        return g:rubycomplete_completions
    endif
endfunction


function! s:DefRuby()
ruby << RUBYEOF
ReservedWords = [
      "BEGIN", "END",
      "alias", "and",
      "begin", "break",
      "case", "class",
      "def", "defined", "do",
      "else", "elsif", "end", "ensure",
      "false", "for",
      "if", "in",
      "module",
      "next", "nil", "not",
      "or",
      "redo", "rescue", "retry", "return",
      "self", "super",
      "then", "true",
      "undef", "unless", "until",
      "when", "while",
      "yield",
    ]

Operators = [ "%", "&", "*", "**", "+",  "-",  "/",
      "<", "<<", "<=", "<=>", "==", "===", "=~", ">", ">=", ">>",
      "[]", "[]=", "^", ]

def identify_type(var)
  @buf = VIM::Buffer.current
  enum = @buf.line_number
  snum = (enum-10).abs
  nums = Range.new( snum, enum )
  regxs = '/.*(%s)\s*=(.*)/' % var
  regx = Regexp.new( regxs )
  nums.each do |x|
    ln = @buf[x]
    #print $~ if regx.match( ln )
  end
end

def load_requires
  @buf = VIM::Buffer.current
  enum = @buf.line_number
  nums = Range.new( 1, enum )
  nums.each do |x|
    ln = @buf[x]
    begin
      eval( "require %s" % $1 ) if /.*require\s*(.*)$/.match( ln )
    rescue Exception
      #ignore?
    end
  end
end

def load_buffer_class(name)
  #print "got: %s" % name
  classdef = get_buffer_entity(name, 'GetBufferRubyClass("%s")')
  return if classdef == nil

  pare = /^\s*class\s*(.*)\s*<\s*(.*)\s*\n/.match( classdef )
  #print "class: %s" % $2 if pare != nil
  load_buffer_class( $2 ) if pare != nil
  mixre = /.*\n\s*include\s*(.*)\s*\n/.match( classdef )
  #print "module: %s" % $2 if mixre != nil
  load_buffer_module( $2 ) if mixre != nil

  #print classdef
  eval classdef 
end

def load_buffer_module(name)
  classdef = get_buffer_entity(name, 'GetBufferRubyModule("%s")')
  return if classdef == nil

  #print classdef
  eval classdef 
end

def get_buffer_entity(name, vimfun)
  @buf = VIM::Buffer.current
  nums = eval( VIM::evaluate( vimfun % name ) )
  #print "%s %s" % [ nums, nums.class ]
  return nil if nums == nil 
  return nil if nums.min == nums.max && nums.min == 0
  
  classdef = ""
  nums.each do |x|
    ln = @buf[x]
    classdef += "%s\n" % ln
  end
 
  return classdef
end

def get_completions(base)
  load_requires
  input = VIM::evaluate('expand("<cWORD>")')
  input += base
  input.lstrip!
  if input.length == 0
    input = VIM::Buffer.current.line
    input.strip!
  end
  message = nil


  case input
    when /^(\/[^\/]*\/)\.([^.]*)$/
      # Regexp
      receiver = $1
      message = Regexp.quote($2)

      candidates = Regexp.instance_methods(true)
      select_message(receiver, message, candidates)

    when /^([^\]]*\])\.([^.]*)$/
      # Array
      receiver = $1
      message = Regexp.quote($2)

      candidates = Array.instance_methods(true)
      select_message(receiver, message, candidates)

    when /^([^\}]*\})\.([^.]*)$/
      # Proc or Hash
      receiver = $1
      message = Regexp.quote($2)

      candidates = Proc.instance_methods(true) | Hash.instance_methods(true)
      select_message(receiver, message, candidates)

    when /^(:[^:.]*)$/
      # Symbol
      if Symbol.respond_to?(:all_symbols)
        sym = $1
        candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
        candidates.grep(/^#{sym}/)
      else
        []
      end

    when /^::([A-Z][^:\.\(]*)$/
      # Absolute Constant or class methods
      receiver = $1
      candidates = Object.constants
      candidates.grep(/^#{receiver}/).collect{|e| "::" + e}

    when /^(((::)?[A-Z][^:.\(]*)+)::?([^:.]*)$/
      # Constant or class methods
      receiver = $1
      message = Regexp.quote($4)
      begin
        candidates = eval("#{receiver}.constants | #{receiver}.methods")
      rescue Exception
        candidates = []
      end
      candidates.grep(/^#{message}/).collect{|e| receiver + "::" + e}

    when /^(:[^:.]+)\.([^.]*)$/
      # Symbol
      receiver = $1
      message = Regexp.quote($2)

      candidates = Symbol.instance_methods(true)
      select_message(receiver, message, candidates)

    when /^([0-9_]+(\.[0-9_]+)?(e[0-9]+)?)\.([^.]*)$/
      # Numeric
      receiver = $1
      message = Regexp.quote($4)

      begin
        candidates = eval(receiver).methods
      rescue Exception
        candidates
      end
      select_message(receiver, message, candidates)

    when /^(\$[^.]*)$/
	  candidates = global_variables.grep(Regexp.new(Regexp.quote($1)))

#   when /^(\$?(\.?[^.]+)+)\.([^.]*)$/
    when /^((\.?[^.]+)+)\.([^.]*)$/
      # variable
      receiver = $1
      message = Regexp.quote($3)
      load_buffer_class( receiver )

      cv = eval("self.class.constants")

      vartype = VIM::evaluate("GetRubyVarType('%s')" % receiver)
      if vartype != ''
        load_buffer_class( vartype )

        begin
          candidates = eval("#{vartype}.instance_methods")
        rescue Exception
          candidates = []
        end
      elsif (cv).include?(receiver)
        # foo.func and foo is local var.
        candidates = eval("#{receiver}.methods")
      elsif /^[A-Z]/ =~ receiver and /\./ !~ receiver
        # Foo::Bar.func
        begin
          candidates = eval("#{receiver}.methods")
        rescue Exception
          candidates = []
        end
      else
        # func1.func2
        candidates = []
        ObjectSpace.each_object(Module){|m|
          next if m.name != "IRB::Context" and
            /^(IRB|SLex|RubyLex|RubyToken)/ =~ m.name
          candidates.concat m.instance_methods(false)
        }
        candidates.sort!
        candidates.uniq!
      end
      #identify_type( receiver )
      select_message(receiver, message, candidates)

    #when /^((\.?[^.]+)+)\.([^.]*)\(\s*\)*$/
        #function call
        #obj = $1
        #func = $3

    when /^\.([^.]*)$/
	# unknown(maybe String)

      receiver = ""
      message = Regexp.quote($1)

      candidates = String.instance_methods(true)
      select_message(receiver, message, candidates)

  else
    print "HERE"
    inclass = eval( VIM::evaluate("IsInClassDef()") )
    print "inclass %s" % inclass

    if inclass != nil
      classdef = "%s\n" % VIM::Buffer.current[ inclass.min ] 
      print "line: %s" % classdef
      found = /^\s*class\s*([A-Za-z0-9]*)(\s*<\s*([A-Za-z0-9]*))?\s*\n$/.match( classdef )
      print "restat: %s" % found.class
      if found != nil
        print "rematch: %s" % $1
        receiver = $1
        message = input
        load_buffer_class( receiver )
        candidates = eval( "#{receiver}.instance_methods" )
        select_message(receiver, message, candidates)
      end
    end
    
    if inclass == nil || found == nil
      candidates = eval("self.class.constants")
      (candidates|ReservedWords).grep(/^#{Regexp.quote(input)}/)
    end
  end

    #print candidates
  if message != nil && message.length > 0
    rexp = '^%s' % message.downcase
    candidates.delete_if do |c|
        c.downcase.match( rexp )
        $~ == nil
    end
  end

  outp = ""
  #    tags = VIM::evaluate("taglist('^%s$')" %
  (candidates-Object.instance_methods).each { |c| outp += "{'word':'%s','item':'%s'}," % [ c, c ] }
  outp.sub!(/,$/, '')
  VIM::command("let g:rubycomplete_completions = [%s]" % outp)
end


def select_message(receiver, message, candidates)
  #tags = VIM::evaluate("taglist('%s')" % receiver)
  #print tags
  candidates.grep(/^#{message}/).collect do |e|
    case e
      when /^[a-zA-Z_]/
        receiver + "." + e
      when /^[0-9]/
      when *Operators
        #receiver + " " + e
    end
  end
  candidates.delete_if { |x| x == nil }
  candidates.uniq!
  candidates.sort!
end
RUBYEOF
endfunction

call s:DefRuby()
" vim: set et ts=4:
