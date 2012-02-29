require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MethodDisabling" do

  describe "instance methods" do
    let(:klass) do
      suppress_warnings do
        ::TheClass = Class.new do
          def the_method(*args, &block)
            original_implementation(*args, &block)
          end

          private

          def original_implementation(*args, &block)
            42
          end
        end
      end
    end

    let(:object) { klass.new }

    context "untouched" do
      it "should call the original implementation" do
        object.should_receive(:original_implementation)
        object.the_method
      end
    end

    context "disabled" do
      before do
        klass.disable_method :the_method
      end

      it "should not call the original implementation" do
        object.should_not_receive(:original_implementation)
        object.the_method rescue nil
      end

      it "should raise NoMethodError with message 'TheClass#the_method is disabled'" do
        expect {
          object.the_method
        }.to raise_error(NoMethodError, "TheClass#the_method is disabled")
      end
    end

    context "restored" do
      before do
        klass.disable_method :the_method
        klass.restore_method :the_method
      end

      it "should call the original implementation" do
        object.should_receive(:original_implementation)
        object.the_method rescue nil
      end

      it "should pass through the method parameters" do
        args = [:foo, 42]
        object.should_receive(:original_implementation).with(*args)
        object.the_method(*args) rescue nil
      end

      it "should pass through any block parameters" do
        yielded   = nil
        the_block = Proc.new { |*args| yielded = args }

        object.should_receive(:original_implementation).and_yield(42)
        object.the_method(&the_block)

        yielded.should == [42]
      end

      it "should not raise an error" do
        expect {
          object.the_method
        }.to_not raise_error
      end
    end

    context "re-disabled" do
      before do
        klass.disable_method :the_method
        klass.restore_method :the_method
        klass.disable_method :the_method
      end

      it "should not call the original implementation" do
        object.should_not_receive(:original_implementation)
        object.the_method rescue nil
      end

      it "should raise NoMethodError with message 'TheClass#the_method is disabled'" do
        expect {
          object.the_method
        }.to raise_error(NoMethodError, "TheClass#the_method is disabled")
      end
    end
  end

end
