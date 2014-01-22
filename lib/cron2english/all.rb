module Cron2English

  DAYS_OF_WEEK = %w{Sun Mon Tue Wed Thu Fri Sat}
  MONTHS = %w{Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec}
  MIL2AMPM = ['midnight', *(1..11).map{|i| "#{i}am"}, 'noon', *(1..11).map{|i| "#{i}pm"}]
  DOW2NUM = Hash[DAYS_OF_WEEK.map(&:downcase).zip(0..6)]
  NUM2DOW = Hash[(0..6).zip(DAYS_OF_WEEK) + [[7, 'Sun']]]
  MONTH2NUM = Hash[MONTHS.map(&:downcase).zip(1..12)]
  NUM2MONTH = Hash[(1..12).zip(MONTHS)]
  # unshift @months, '';    # What is this about??
  DOW_REGEX = %r{^(#{DAYS_OF_WEEK.join("|")})$}i
  MONTH_REGEX = %r{^(#{MONTHS.join("|")}|)$}i
  NUM2MONTH_LONG = Hash[(1..12).zip(%w{January February March April May June July August September October November December})]
  NUM2DOW_LONG = %w{Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday}
  ATOM = '\d+|(?:\d+-\d+(?:/\d+)?)'
  ATOMS_REGEX = %r{^(?:#{ATOM})(?:,#{ATOM})*$}i
  AT_WORDS = {
    'reboot'   => 'At reboot',
    'yearly'   => 'Yearly (midnight on January 1st)',
    'annually' => 'Yearly (midnight on January 1st)',
    'monthly'  => 'Monthly (midnight on the first of every month)',
    'weekly'   => 'Weekly (midnight every Sunday)',
    'daily'    => 'Daily, at midnight',
    'midnight' => 'Daily, at midnight',
    'hourly'   => 'At the top of every hour'
  }

  def self.parse(str)
    parser = Cron2English::Parser.new
    parser.parse(str)
  end

  class Parser

    def initialize
      @dow = nil
      @month = nil
      @dow2num = {}
      @month2num = {}
      @num2dow = {}
      @num2month = {}
    end

    def parse(str)
      str = str.strip

      if str =~ /^@(\w+)$/ and AT_WORDS[$1.downcase]
        process_vixie($1)
      else
        bits = str.split(/[ \t]+/)
        if bits.size == 5
          process_trad(*bits)
        else
          give_up(str)
        end
      end
    end

    private

    def process_vixie(str)
      [str]
    end

    def process_trad(m, h, day_of_month, month, dow)
      month = MONTH2NUM[$1.downcase] if month =~ MONTH_REGEX
      month = month.to_s if month
      dow = DOW2NUM[$1.downcase] if dow =~ DOW_REGEX
      dow = dow.to_s if dow
      bits = [m, h, day_of_month, month, dow]
      unparseable = []
      bits_segmented = []
      bits.each_with_index do |bit, i|
        segments = []
        if bit == '*'
          segments << ['*']

        elsif bit =~ %r<^\*/(\d+)$>
          # a hack for "*/3" etc
          segments << ['*', $1.to_i]

        elsif bit =~ ATOMS_REGEX
          bit.split(',').each do |thang|
            if thang =~ %r<^(?:(\d+)|(?:(\d+)-(\d+)(?:/(\d+))?))$>
              if $1
                segments << [$1.to_i]
              elsif $4
                segments << [$2.to_i, $3.to_i, $4.to_i]
              else
                segments << [$2.to_i, $3.to_i]
              end
            else
              unparseable << ("field %s: \"%s\"" % [i + 1, bit])
            end
          end
        else
          unparseable << ("field %s: \"%s\"" % [i + 1, bit])
        end
        bits_segmented << segments
      end

      give_up(unparseable.join("; ")) if unparseable.size > 0
      bits_to_english(bits_segmented)
    end

    def bits_to_english(bits)
      # This is the deep ugly scary guts of this program.
      # The older and eldritch among you might recognize this as sort of a
      # parody of bad old Lisp style of data-structure handling.
      time_lines = []


      #######################################################################
      # Render the minutes and hours
      if bits[0].size   == 1   and bits[1].size    == 1 and
        bits[0][0].size == 1   and bits[1][0].size == 1 and
        bits[0][0][0]   != '*' and bits[1][0][0]   != '*'
        # It's a highly simplifiable time expression!
        # This is a very common case.  Like "46 13" -> 1:46pm
        # Formally: when minute and hour are each a single number.

        h = bits[1][0][0]
        if bits[0][0][0] == 0
          # Simply at the top of the hour, so just call it by the hour name.
          time_lines << MIL2AMPM[h]

        else
          # Can't say "noon:02", so use an always-numeric time format:
          time_lines << "%s:%02d%s" % [
            (h > 12) ? (h - 12) : h,
            bits[0][0][0],
            (h >= 12) ? 'pm' : 'am'
          ]
        end
        time_lines[time_lines.size - 1] += ' on'

      else
        # It's not a highly simplifiable time expression

        # First, minutes:
        if bits[0][0][0] == '*'
          if bits[0][0].size == 1 or bits[0][0][1] == 1
            time_lines << 'every minute of'
          else
            time_lines << "every #{freq(bits[0][0][1])} minute of"
          end

        elsif bits[0].size == 1 and bits[0][0][0] == 0
          # It's just a '0'.  Ignore it -- instead of bothering
          # to add a "0 minutes past"

        elsif bits[0].none?{|x| x.size > 1}
          # It's all like 7,10,15. Conjoinable
          time_lines << conj_and(bits[0].map{|x| x[0]}) + (bits[0][-1][0] == 1 ? ' minute past' : ' minutes past')

        else
          # It's just gonna be long.
          hunks = []
          bits[0].each do |bit|
            if bit.size == 1  # "7"
              hunks << (bit[0] == 1 ? '1 minute' : "#{bit[0]} minutes")

            elsif bit.size == 2 # "7-9"
              hunks << ("from %d to %d %s" % [*bit, bit[1] == 1 ? 'minute' : 'minutes'])

            elsif bit.size == 3 # "7-20/2"
              hunks << ("every %d %s from %d to %d" % [bit[2],
                                                       bit[2] == 1 ? 'minute' : 'minutes',
                                                       bit[0],
                                                       bit[1]])
            end
          end
          time_lines << (conj_and(hunks) + " past")
        end

        # Now hours
        if bits[1][0][0] == '*'
          if bits[1][0].size == 1 or bits[1][0][1] == 1
            time_lines << 'every hour of'
          else
            time_lines << "every #{freq(bits[1][0][1])} hour of"
          end

        else
          hunks = []
          bits[1].each do |bit|
            if bit.size == 1 # "7"
              hunks << (MIL2AMPM[bit[0]] || "HOUR_#{bit[0]}??")

            elsif bit.size == 2 # "7-9"
              hunks << ("from %s to %s" % [MIL2AMPM[bit[0]] || "HOUR_#{bit[0]}??",
                                           MIL2AMPM[bit[1]] || "HOUR_#{bit[1]}??"])

            elsif bit.size == 3 # "7-20/2"
              hunks << ("every %d %s from %s to %s" % [bit[2],
                                                       bit[2] == 1 ? 'hour' : 'hours',
                                                       MIL2AMPM[bit[0]] || "HOUR_#{bit[0]}??",
                                                       MIL2AMPM[bit[1]] || "HOUR_#{bit[2]}??"])
            end
          end
          time_lines << (conj_and(hunks) + " of")
        end
      end
      # End of hours and minutes

      #######################################################################
      # Day-of-month

      if bits[2][0][0] == '*'
        time_lines[-1].gsub!(/ on$/, '')
        if bits[2][0].size == 1 or bits[2][0][1] == 1
          time_lines << 'every day of'
        else
          time_lines << "every #{freq(bits[2][0][1])} day of"
        end
      else
        hunks = []
        bits[2].each do |bit|
          if bit.size == 1  # "7"
            hunks << "the #{ordinate(bit[0])}"

          elsif bit.size == 2 # "7-9"
            hunks << ("from the %s to the %s" % [ordinate(bit[0]), ordinate(bit[1])])

          elsif bit.size == 3 # "7-20/2"
            hunks << ("every %d %s from the %s to the %s" % [bit[2],
                                                             bit[2] == 1 ? 'day' : 'days',
                                                             ordinate(bit[0]),
                                                             ordinate(bit[1])])
          end
        end

        # collapse the "the"s, if all the elements have one
        if hunks.size > 1 and hunks.none?{|h| h !~ /^the /}
          hunks = hunks.map{|h| h.gsub(/^the /, '')}
          hunks[0] = "the #{hunks[0]}"
        end

        time_lines << "#{conj_and(hunks)} of"
      end

      #######################################################################
      # Month

      if bits[3][0][0] == '*'
        if bits[3][0].size == 1 or bits[3][0][1] == 1
          time_lines << 'every month'
        else
          time_lines << "every #{freq(bits[3][0][1])} month"
        end
      else
        hunks = []
        bits[3].each do |bit|
          if bit.size == 1 # "7"
            hunks << (NUM2MONTH_LONG[bit[0]] || "MONTH_#{bit[0]}??")

          elsif bit.size == 2 # "7-9"
            hunks << ("from %s to %s" % [NUM2MONTH_LONG[bit[0]] || "MONTH_#{bit[0]}??",
                                         NUM2MONTH_LONG[bit[1]] || "MONTH_#{bit[1]}??"])

          elsif bit.size == 3 # "7-20/2"
            hunks << ("every %d %s from %s to %s" % [bit[2],
                                                     bit[2] == 1 ? 'month' : 'months',
                                                     NUM2MONTH_LONG[bit[0]] || "MONTH_#{bit[0]}??",
                                                     NUM2MONTH_LONG[bit[1]] || "MONTH_#{bit[1]}??"])
          end
        end

        time_lines << conj_and(hunks)
      end

      #######################################################################
      # Weekday
     #
    #
   #
  #
  # From man 5 crontab:
  #   Note: The day of a command's execution can be specified by two fields
  #   -- day of month, and day of week.  If both fields are restricted
  #   (ie, aren't *), the command will be run when either field matches the
  #   current time.  For example, "30 4 1,15 * 5" would cause a command to
  #   be run at 4:30 am on the 1st and 15th of each month, plus every Friday.
  #
  # [But if both fields ARE *, then it just means "every day".
  #  and if one but not both are *, then ignore the *'d one --
  #  so   "1 2 3 4 *" means just 2:01, April 3rd
  #  and  "1 2 * 4 5" means just 2:01, on every Friday in April
  #  But  "1 2 3 4 5" means 2:01 of every 3rd or Friday in April. ]
  #
   #
    #
     #
      # And that's a bit tricky.

      if bits[4][0][0] == '*' and (bits[4][0].size == 1 or bits[4][0][1] == 1)
        # Most common case: any weekday. Do nothing really.
        #
        # Hmm, does "*/1" really many "*" here, given the above note?

        # Tidy things up while we're here:
        if time_lines[-2] == 'every day of' and
           time_lines[-1] == 'every month'
          time_lines[-2] == 'every day'
          time_lines.pop
        end

      else
        # Ugh, there's some restriction on weekdays.

        # Translate the DOW-expression
        expression = nil
        hunks = []
        bits[4].each do |bit|
          if bit.size == 1
            hunks << (NUM2DOW_LONG[bit[0]] || "DOW_#{bit[0]}??")

          elsif bit.size == 2
            if bit[0] == '*'  # It's like */3
              # hunks << ("every %s day of the week" % freq(bit[1]))
              # The above was ambiguous: "every third day of the week"
              # sounds synonymous with just "3"
              if bit[1] == 2
                # common and unambiguous case.
                hunks << "every other day of the week"
              else
                # rare cases: N > 2
                hunks << "every #{bit[1]} days of the week"
                # sounds clunky, but it's a clunky concept
              end
            
            else
              # It's like "7-9"
              hunks << ("%s through %s" % [NUM2DOW_LONG[bit[0]] || "DOW_#{bit[0]}??",
                                           NUM2DOW_LONG[bit[1]] || "DOW_#{bit[1]}??"])
            end

          elsif bit.size == 3 # "7-20/2"
            hunks << ("every %s %s from %s through %s" % [ordinate_soft(bit[2]),
                                                          'day',
                                                          NUM2DOW_LONG[bit[0]] || "DOW_#{bit[0]}??",
                                                          NUM2DOW_LONG[bit[1]] || "DOW_#{bit[1]}??"])
          end
        end
        expression = conj_or(hunks)

        # Now figure out where to put it. . . .

        if time_lines[-2] == 'every day of'
          # Unrestricted day-of-month, hooray.
          if time_lines[-1] == 'every month'
            # change it to "every Thursday", killing the "of every month"
            time_lines[-2] = "every #{expression}"
            time_lines[-2].gsub!(%r{every every }, 'every ')
            time_lines.pop
          else
            # change it to "every Thursday in"
            time_lines[-2] = "every #{expression} in"
            time_lines[2].gsub!(%r{every every }, 'every ')
          end
        else
          # This is the messy case where there's a DOM and DOW restriction

          time_lines[-2] += " -- or every #{expression} in --"
          # Yes, dashes look very strange, but then this is a very rare case.
          time_lines[-2].gsub!(%r{every every }, 'every ')
        end
      end
      time_lines[-1].sub!(/ of$/, '')
      return time_lines
    end

    def conj_and(bits)
      if bits.grep(/every|from/).any?
        # put in semicolons in case of complex constituency
        return bits.join('; and ') if bits.size < 2
        last = bits.pop
        return "#{bits.join('; ')}; and #{last}"
      else
        return bits.join(' and ') if bits.size < 3
        last = bits.pop
        return "#{bits.join(', ')}, and #{last}"
      end
    end

    def conj_or(bits)
      if bits.grep(/every|from/).any?
        # put in semicolons in case of complex constituency
        return bits.join('; or ') if bits.size < 2
        last = bits.pop
        return "#{bits.join('; ')}; or #{last}"
      else
        return bits.join(' or ') if bits.size < 3
        last = bits.pop
        return "#{bits.join(', ')}, or #{last}"
      end
    end

    ORDINATIONS = %w{zeroth first second third fourth fifth sixth seventh eighth ninth tenth}

    def ordsuf(n=nil)
      return 'th' if not n or n.to_i == 0
      # 'th' for undef, 0, or anything non-number
      n = n.abs
      return 'th' unless n == n.to_i
      n %= 100
      return 'th' if n == 11 or n == 12 or n == 13
      n %= 10
      return 'st' if n == 1
      return 'nd' if n == 2
      return 'rd' if n == 3
      return 'th'
    end

    def ordinate(n=0)
      ORDINATIONS[n] || "#{n}#{ordsuf(n)}"
    end

    def freq(n=0)
      # frequentive form. Like ordinal, except that 2 -> 'other'
      # (as in every other)
      return 'other' if n == 2
      ORDINATIONS[n] || "#{n}#{ordsuf(n)}"
    end

    def ordinate_soft(n=0)
      "#{n}#{ordsuf(n)}"
    end

    def give_up(str)
      raise "Unparseable crontab spec: #{str}"
    end


  end

end
