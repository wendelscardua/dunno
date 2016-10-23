require 'distribution'
class GeneticAlgorithm
  attr_reader :num_chromosomes, :chromosomes, :elite_chromosomes
  attr_writer :elite_chromosomes
  MUTATION_CHANCE = 0.05
  CROSSOVER_CHANCE = 0.7

  def initialize(num_chromosomes)
    @num_chromosomes = num_chromosomes
    @chromosomes = (1..num_chromosomes).map { |_| Chromosome.new }
    @elite_chromosomes = 0
  end

  def step_over
    next_generation = []
    sort_chromosomes if @elite_chromosomes > 0
    while next_generation.count < num_chromosomes
      left = fetch_chromosome_by_roulette
      right = fetch_chromosome_by_roulette
      left, right = left.crossover(right) if rand < CROSSOVER_CHANCE
      left = left.mutate(MUTATION_CHANCE)
      right = right.mutate(MUTATION_CHANCE)
      next_generation << left
      next_generation << right
    end
    @chromosomes = next_generation
  end

  def fetch_chromosome_by_roulette
    total_fit = 0.0
    count = 0
    chromosomes.each do |chromosome|
      if elite_chromosomes > 0
        count += 1
        break if count > elite_chromosomes
      end
      total_fit += chromosome.normalized_fitness
    end
    slice = rand * total_fit
    chromosomes.each do |chromosome|
      slice -= chromosome.normalized_fitness
      return chromosome if slice <= 0.0
    end
    chromosomes.first
  end

  def sort_chromosomes
    @chromosomes.sort_by! { |chromosome| -chromosome.fitness }
  end
end

class Chromosome
  attr_reader :fitness, :genome
  attr_writer :fitness, :genome

  def initialize(genome = nil)
    @genome = genome ||
              Hash[
                Chromosome.genome.map do |gene_name, kind|
                  case kind
                  when :float then [gene_name, 2 * (rand - rand)]
                  when :binary then [gene_name, (rand * 2).to_i]
                  else raise "Invalid type #{kind} for gene #{gene_name}"
                  end
                end
              ]
    @fitness = 0.0
  end

  def dna
    @genome.values.reduce('') do |a, e|
      a + (
        if e < -0.5
          'C'
        elsif e < 0.0
          'T'
        elsif e < 0.5
          'A'
        else
          'G'
        end
      )
    end
  end

  def normalized_fitness
    if fitness <= 1.0
      1.0
    else
      fitness
    end
  end

  def mutate(mutation_chance)
    Chromosome.new Hash[
                     @genome.map do |gene, value|
                       if rand < mutation_chance
                         [gene, mutate_value(gene)]
                       else
                         [gene, value]
                       end
                     end
                   ]
  end

  def mutate_value(gene)
    case Chromosome.genome[gene]
    when :float
      genome[gene] + Chromosome.random_gaussian
    when :binary
      1 - genome[gene]
    else raise "Invalid gene #{gene}"
    end
  end

  def crossover(other)
    pos = (rand * genome.count).to_i
    [
      Chromosome.new(Hash[genome.to_a[0...pos] +
                          other.genome.to_a[pos...genome.count]]),
      Chromosome.new(Hash[other.genome.to_a[0...pos] +
                          genome.to_a[pos...genome.count]])
    ]
  end

  def to_s
    genome.inspect
  end

  class << self
    def genome
      @genome ||= {}
    end

    def gene(name, kind)
      genome[name] = kind
      self
    end

    def random_gaussian
      gaussian_source.call
    end

    def gaussian_source
      @gaussian_source ||= Distribution::Normal.rng(1)
    end
  end
end
