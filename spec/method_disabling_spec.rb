require File.expand_path(File.dirname(__FILE__) + '/spec_helper')


shared_examples "enabled method" do

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

  it "should return the original implementation's return value" do
    return_value = rand
    object.should_receive(:original_implementation).and_return(return_value)
    object.the_method.should == return_value
  end

  it "should not raise an error" do
    expect {
      object.the_method
    }.to_not raise_error
  end

end


shared_examples "disabled method" do

  it "should not call the original implementation" do
    object.should_not_receive(:original_implementation)
    object.the_method rescue nil
  end

  it "should raise NoMethodError with default message" do
    expect {
      object.the_method
    }.to raise_error(NoMethodError, "#{klass_inspect}#the_method is disabled")
  end

end


shared_examples "method disabling" do

  context "untouched" do
    it_should_behave_like "enabled method"
  end

  context "disabled" do
    context "with default message" do
      before do
        klass.send(disabler, :the_method)
      end

      it_should_behave_like "disabled method"
    end

    context "with custom message" do
      let(:message) { "Custom Message" }

      before do
        klass.send(disabler, :the_method, message)
      end

      it "should raise NoMethodError with custom message" do
        expect {
          object.the_method
        }.to raise_error(NoMethodError, message)
      end
    end
  end

  context "restored" do
    before do
      klass.send(disabler, :the_method)
      klass.send(restorer, :the_method)
    end

    it_should_behave_like "enabled method"
  end

  context "re-disabled" do
    context "with default message" do
      before do
        klass.send(disabler, :the_method)
        klass.send(restorer, :the_method)
        klass.send(disabler, :the_method)
      end

      it_should_behave_like "disabled method"
    end

    context "with custom message" do
      let(:message) { "Custom Message" }

      before do
        klass.send(disabler, :the_method, message)
        klass.send(restorer, :the_method)
        klass.send(disabler, :the_method)
      end

      it "should raise NoMethodError with custom message" do
        expect {
          object.the_method
        }.to raise_error(NoMethodError, message)
      end
    end
  end

end


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

    let(:object)        { klass.new }
    let(:disabler)      { :disable_method }
    let(:restorer)      { :restore_method }
    let(:klass_inspect) { klass.inspect }

    include_examples "method disabling"
  end

  describe "class methods" do
    let(:klass) do
      suppress_warnings do
        ::TheClass = Class.new do
          def self.the_method(*args, &block)
            original_implementation(*args, &block)
          end

          def self.original_implementation(*args, &block)
          end
          private_class_method :original_implementation
        end
      end
    end

    let(:object)        { klass }
    let(:disabler)      { :disable_class_method }
    let(:restorer)      { :restore_class_method }
    let(:klass_inspect) { klass.singleton_class.inspect }

    include_examples "method disabling"
  end

end
