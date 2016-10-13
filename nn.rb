class Neuron
  attr_reader :num_inputs, :weights

  def initialize(num_inputs)
    @num_inputs = num_inputs
    @weights = (0..num_inputs).map { |_| rand - rand }
  end
end

class NeuronLayer
  attr_reader :num_neurons, :neurons

  def initialize(num_neurons, inputs_per_neuron)
    @num_neurons = num_neurons
    @neurons = (1..num_neurons).map { |_| Neuron.new(inputs_per_neuron) }
  end
end

class NeuralNetwork
  attr_reader :num_inputs, :num_outputs,
              :num_hidden_layers, :num_neurons_per_hidden_layer,
              :layers

  D_BIAS = -1.0
  D_ACTIVATION_RESPONSE = 1.0

  def initialize(num_inputs, num_outputs, num_hidden_layers, num_neurons_per_hidden_layer)
    @num_inputs = num_inputs
    @num_outputs = num_outputs
    @num_hidden_layers = num_hidden_layers
    @num_neurons_per_hidden_layer = num_neurons_per_hidden_layer
    @layers = []

    if @num_hidden_layers > 0
      # create first hidden layer
      @layers << NeuronLayer.new(@num_neurons_per_hidden_layer, @num_inputs)
      (1..(@num_hidden_layers - 1)).each do
        @layers << NeuronLayer.new(@num_neurons_per_hidden_layer,
                                   @num_neurons_per_hidden_layer)
      end
      @layers << NeuronLayer.new(@num_outputs, @num_neurons_per_hidden_layer)

    else
      # create output layer
      @layers << NeuronLayer.new(@num_outputs, @num_inputs)
    end
  end

  def weights
    # this will hold the weights
    @weights = []
    @layers.each do |layer|
      layer.neurons.each do |neuron|
        neuron.weights.each do |weight|
          @weights << weight
        end
      end
    end
    @weights
  end

  def weights=(weights)
    count = 0
    @layers.each do |layer|
      layer.neurons.each do |neuron|
        neuron.weights.each_with_index do |_weight, i|
          neuron.weights[i] = weights[count]
          count += 1
        end
      end
    end
  end

  def apply(input)
    raise 'Invalid input size' unless input.count == num_inputs
    @output = nil
    @layers.each do |layer|
      @output = layer.neurons.map do |neuron|
        net_input = (0...input.count).reduce(0.0) do |a, e|
          a + input[e] * neuron.weights[e]
        end
        net_input += neuron.weights.last * D_BIAS
        # we can store the outputs from each layer as we generate them.
        # The combined activation is first filtered through the sigmoid
        # function
        sigmoid(net_input, D_ACTIVATION_RESPONSE)
      end
      input = @output
    end
    @output
  end

  def sigmoid(net_input, response)
    1.0 / (1.0 + Math.exp(-net_input / response))
  end
end
