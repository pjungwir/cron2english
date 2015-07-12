require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Cron2English do

  [
    ["40 5 * * *", ["5:40am", "every day"]],
    ["0 5 * * 1", ["5am", "every Monday"]],
    ["10 8 15 * *", ["8:10am on", "the 15th of", "every month"]],
    ["40 5 * * *", ["5:40am", "every day"]],
    ["50 6 * * 1", ["6:50am", "every Monday"]],
    ["1 2 * apr mOn", ["2:01am", "every Monday in", "April"]],
    ["1 2 * apr mon-fri", ["2:01am", "every Monday through Friday in", "April"]],
    ["1 2 * apr-jun mOn", ["2:01am", "every Monday in", "from April to June"]],
    ["1 2 3 4 7", ["2:01am on", "the third of -- or every Sunday in --", "April"]],
    ["1-20/3 * * * *", ["every 3 minutes from 1 to 20 past", "every hour of", "every day"]],
    ["1,2,3 * * * *", ["1, 2, and 3 minutes past", "every hour of", "every day"]],
    ["1-9,15-30 * * * *", ["from 1 to 9 minutes; and from 15 to 30 minutes past", "every hour of", "every day"]],
    ["1-9/3,15-30/4 * * * *", ["every 3 minutes from 1 to 9; and every 4 minutes from 15 to 30 past", "every hour of", "every day"]],
    ["1 2 3 jan mon", ["2:01am on", "the third of -- or every Monday in --", "January"]],
    ["1 2 3 4 mON", ["2:01am on", "the third of -- or every Monday in --", "April"]],
    ["1 2 3 jan 5", ["2:01am on", "the third of -- or every Friday in --", "January"]],
    ["@reboot", ["reboot"]],
    ["@yearly", ["yearly"]],
    ["@annually", ["annually"]],
    ["@monthly", ["monthly"]],
    ["@weekly", ["weekly"]],
    ["@daily", ["daily"]],
    ["@midnight", ["midnight"]],
    ["@hourly", ["hourly"]],
    ["*/3 * * * *", ["every third minute of", "every hour of", "every day"]],
    ["0 5 * 2,3 *", ["5am", "every day of", "February and March"]],
  ].each do |cronspec, english|
    it "should parse the cronspec #{cronspec}" do
      result = Cron2English.parse(cronspec)
      result.should == english
    end
  end

  it "should raise an exception on bad input" do
    expect {
      Cron2English.parse("not a time spec")
    }.to raise_error(Cron2English::ParseException)
  end

end
