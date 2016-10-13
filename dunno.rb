require 'gosu'
require './nn'
require './ga'

module ZOrder
  BACKGROUND = 0
  STARS = 1
  PLAYER = 2
  UI = 3
end

# Main Window for... I dunno
class MainWindow < Gosu::Window
  WIDTH = 1000
  HEIGHT = 720
  FLEET_SIZE = 32
  ITERATIONS = 1000

  attr_reader :fleet, :stars

  def initialize
    super(WIDTH, HEIGHT)
    self.caption = 'Hello World!'
    @background_image = Gosu::Image.new('media/space.png', tileable: true)

    @player = Ship.new
    @player.warp(WIDTH / 2, HEIGHT / 2)

    brain.weights.each_with_index { |_w, i| Chromosome.gene("w_#{i}", :float) }

    @ga = GeneticAlgorithm.new FLEET_SIZE

    @fleet = @ga.chromosomes.map do |chromosome|
      ship = Ship.new(brain)
      ship.brain.weights = chromosome.genome.values
      ship
    end

    @fleet.each { |ship| ship.warp(rand * WIDTH, rand * HEIGHT) }

    @star_anim = Gosu::Image.load_tiles('media/star.png', 25, 25)
    @stars = []

    @iterations = 0
    @generations = 1
  end

  def brain
    # input, output, hidden layers, neurons per layer
    NeuralNetwork.new 3, 4, 2, 5
  end

  def update
    if Gosu.button_down?(Gosu::KbLeft) || Gosu.button_down?(Gosu::GpLeft)
      @player.turn_left
    end
    if Gosu.button_down?(Gosu::KbRight) || Gosu.button_down?(Gosu::GpRight)
      @player.turn_right
    end
    if Gosu.button_down?(Gosu::KbUp) || Gosu.button_down?(Gosu::GpButton0)
      @player.accelerate
    end
    @player.move

    @fleet.each do |ship|
      ship.think(environment: self)
    end
    @fleet.each(&:move)

    ([@player] + @fleet).each { |ship| ship.collect_stars(@stars) }

    @stars.push(Star.new(@star_anim)) if rand < 0.08 && @stars.size < 25

    @iterations += 1
    if @iterations >= ITERATIONS
      @iterations = 0
      puts 'G.A. iteration!'
      puts "Generation #{@generations}"
      @generations += 1
      puts @fleet.map(&:score).inspect
      @ga.chromosomes.each_with_index do |chromosome, index|
        weights = @fleet[index].brain.weights
        chromosome.genome.each do |key, _value|
          chromosome.genome[key] = weights.shift
        end
        chromosome.fitness = @fleet[index].score
        @fleet[index].score = 0
      end
      @ga.step_over
      @ga.chromosomes.each_with_index do |chromosome, index|
        @fleet[index].brain.weights = chromosome.genome.values
      end
    end
  end

  def draw
    @player.draw
    @fleet.each(&:draw)
    @background_image.draw(0, 0, ZOrder::BACKGROUND)
    @stars.each(&:draw)
  end

  def button_down(id)
    close if id == Gosu::KbEscape
  end
end

# Ship
class Ship
  attr_reader :brain, :score
  attr_writer :brain, :score

  def initialize(brain = nil)
    @image = Gosu::Image.new('media/starfighter.bmp')
    @x = @y = @vel_x = @vel_y = @angle = 0.0
    @score = 0
    @brain = brain
  end

  def warp(x, y)
    @x = x
    @y = y
  end

  def turn_left
    @angle -= 4.5
  end

  def turn_right
    @angle += 4.5
  end

  def accelerate
    @vel_x += Gosu.offset_x(@angle, 0.125)
    @vel_y += Gosu.offset_y(@angle, 0.125)
  end

  def move
    @x += @vel_x
    @y += @vel_y
    @x = @x % MainWindow::WIDTH
    @y = @y % MainWindow::HEIGHT

    @vel_x *= 0.95
    @vel_y *= 0.95
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::PLAYER, @angle)
  end

  def think(environment: nil)
    return if environment.nil?
    near_star = environment.stars.first
    return if near_star.nil?
    distance = Float::INFINITY
    environment.stars.each do |star|
      sd = (star.x - @x)**2 + (star.y - @y)**2
      if sd < distance
        near_star = star
        distance = sd
      end
    end
    input = [
      @angle,
      (@x - near_star.x) / MainWindow::WIDTH,
      (@y - near_star.y) / MainWindow::HEIGHT
    ]
    output = brain.apply(input)
    puts "Brain #{self} Input [#{input}] Output [#{output}]"
    if output[2] > output[3]
      accelerate
    elsif output[0] > output[1]
      turn_left
    else
      turn_right
    end
  end

  def collect_stars(stars)
    if stars.reject! { |star| Gosu.distance(@x, @y, star.x, star.y) < 20 }
      @score += 1
    end
  end
end

# Star
class Star
  attr_reader :x, :y

  def initialize(animation)
    @animation = animation
    @color = Gosu::Color.new(0xff_000000)
    @color.red = rand(256 - 40) + 40
    @color.green = rand(256 - 40) + 40
    @color.blue = rand(256 - 40) + 40
    @x = rand * MainWindow::WIDTH
    @y = rand * MainWindow::HEIGHT
  end

  def draw
    img = @animation[Gosu.milliseconds / 100 % @animation.size]
    img.draw(@x - img.width / 2.0, @y - img.height / 2.0,
             ZOrder::STARS, 1, 1, @color, :add)
  end
end

window = MainWindow.new
window.show
