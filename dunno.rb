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
  WIDTH = 1200
  HEIGHT = 768
  FLEET_SIZE = 32
  ITERATIONS = 4_000
  STARS = 40
  # wrap_around, collide or reflect
  WALL_MODE = :wrap_around
  attr_reader :fleet, :stars

  def initialize
    super(WIDTH, HEIGHT)
    self.caption = 'Hello World!'
    @background_image = Gosu::Image.new('media/space.png', tileable: true)

    @player = Ship.new
    @player.warp(WIDTH / 2, HEIGHT / 2)

    brain.weights.each_with_index { |_w, i| Chromosome.gene("w_#{i}", :float) }

    @ga = GeneticAlgorithm.new FLEET_SIZE
    @ga.elite_chromosomes = FLEET_SIZE * 0.75
    @fleet = @ga.chromosomes.map do |chromosome|
      puts chromosome.dna
      ship = Ship.new(brain)
      ship.brain.weights = chromosome.genome.values
      ship
    end

    @fleet.each { |ship| ship.warp(rand * WIDTH, rand * HEIGHT) }

    @star_anim = Gosu::Image.load_tiles('media/star.png', 25, 25)
    @stars = (1..STARS).map { |_| Star.new(@star_anim) }
    @iterations = 0
    @generations = 1
  end

  def brain
    # input, output, hidden layers, neurons per layer
    NeuralNetwork.new 7, 3, 3, 12
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
    speed_buffer = 1
    speed_buffer = 200_000 if Gosu.button_down?(Gosu::KbTab)
    @player.move

    speed_buffer.times do
      @fleet.each do |ship|
        ship.think(environment: self)
      end
      @fleet.each(&:move)

      ([@player] + @fleet).each { |ship| ship.collect_stars(@stars) }

      @stars.push(Star.new(@star_anim)) while @stars.size < STARS

      @iterations += 1
      next unless @iterations >= ITERATIONS
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
        puts "#{index} => #{chromosome.dna}"
      end
      @fleet.each(&:reset)
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

  def nearest_star(ship)
    best_star = nil
    best_distance = Float::INFINITY
    fov = 30.0 * Math::PI / 180.0
    stars.each do |star|
      star_angle = Gosu.angle(ship.x, ship.y, star.x, star.y)
      delta = (star_angle - ship.angle).abs
      delta = 2 * Math::PI - delta if delta > Math::PI
      next unless delta <= fov
      distance = (ship.x - star.x)**2 + (ship.y - star.y)**2
      if distance < best_distance
        best_star = star
        best_distance = distance
      end
    end
    best_star
  end
end

# Ship
class Ship
  attr_reader :brain, :score, :color, :angle, :x, :y, :wall_collided
  attr_writer :brain, :score

  def initialize(brain = nil)
    @image = Gosu::Image.new('media/starfighter.bmp')
    @x = @y = 0.0
    @brain = brain
    reset
  end

  def reset
    @vel_x = @vel_y = @angle = 0.0
    @score = 0.0
    @color = Gosu::Color.new(0xff_000000)
    @color.red = rand(256 - 40) + 40
    @color.green = rand(256 - 40) + 40
    @color.blue = rand(256 - 40) + 40
    @wall_collided = false
  end

  def warp(x, y)
    @x = x
    @y = y
  end

  def turn_left
    @angle -= 2.25
    @angle += 360.0 while @angle < 0
  end

  def turn_right
    @angle += 2.25
    @angle -= 360.0 while @angle > 360.0
  end

  def accelerate
    @vel_x += Gosu.offset_x(@angle, 0.0625)
    @vel_y += Gosu.offset_y(@angle, 0.0625)
  end

  def move
    @wall_collided = false
    old_x = @x
    old_y = @y
    @x += @vel_x
    @y += @vel_y
    case MainWindow::WALL_MODE
    when :reflect
      if @x < 0.0 || @x >= MainWindow::WIDTH
        @x = old_x
        @vel_x = -@vel_x
        @angle = -@angle
        @wall_collided = true
      end
      if @y < 0.0 || @y >= MainWindow::HEIGHT
        @y = old_y
        @vel_y = -@vel_y
        @angle = 180.0 - @angle
        @wall_collided = true
      end
    when :collide
      if @x < 0.0 || @x >= MainWindow::WIDTH
        @x = old_x
        @wall_collided = true
      end
      if @y < 0.0 || @y >= MainWindow::HEIGHT
        @y = old_y
        @wall_collided = true
      end
    when :wrap_around
      @x += MainWindow::WIDTH if @x < 0.0
      @x -= MainWindow::WIDTH if @x >= MainWindow::WIDTH
      @y += MainWindow::HEIGHT if @y < 0.0
      @y -= MainWindow::HEIGHT if @y >= MainWindow::HEIGHT
    end
    @vel_x *= 0.95
    @vel_y *= 0.95
  end

  def draw
    @image.draw_rot(@x, @y, ZOrder::PLAYER, @angle, 0.5, 0.5, 1, 1, @color, :add)
  end

  def think(environment: nil)
    return if environment.nil? || environment.stars.count == 0
    near_star = environment.nearest_star(self)

    rad_angle = @angle / 180.0 * Math::PI
    input = [
      Math.sin(rad_angle),
      Math.cos(rad_angle),
      near_star.nil? ? -1.0 : 1.0,
      near_star.nil? ? 0.0 : (near_star.x - @x) / MainWindow::WIDTH,
      near_star.nil? ? 0.0 : (near_star.y - @y) / MainWindow::HEIGHT,
      near_star.nil? ? -Math::PI : compare_hue(@color.hue, near_star.color.hue) / 180.0 * Math::PI,
      @wall_collided ? -1.0 : 1.0
    ]
    output = brain.apply(input)
    accelerate if output[2] > 0.5
    if output[0] > 0.5 || output[1] > 0.5
      if output[0] > output[1]
        turn_left
      else
        turn_right
      end
    end
  end

  def compare_hue(x, y)
    delta = (x - y).abs
    delta = 360.0 - delta if delta > 180.0
    delta
end

  def collect_stars(stars)
    stars.reject! do |star|
      next unless Gosu.distance(@x, @y, star.x, star.y) < 20
      delta_hue = compare_hue(star.color.hue, color.hue)
      if delta_hue > 150.0
        @score += 50.0
      elsif delta_hue > 90.0
        @score += 10.0
      elsif delta_hue > 30.0
        @score -= 5.0
      else
        @score -= 10.0
      end
      true
    end
  end
end

# Star
class Star
  attr_reader :x, :y, :color

  def initialize(animation)
    @animation = animation
    @color = Gosu::Color.new(0xff_000000)
    if rand < 1.0 / 3.0
      @color.red = 255
    elsif rand < 0.5
      @color.green = 255
    else
      @color.blue = 255
    end
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
