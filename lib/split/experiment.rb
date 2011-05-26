module Split
  class Experiment
    attr_accessor :name
    attr_accessor :alternative_names
    attr_accessor :winner

    def initialize(name, *alternative_names)
      @name = name.to_s
      @alternative_names = alternative_names
    end

    def winner
      if w = Split.redis.hget(:experiment_winner, name)
        return Split::Alternative.find(w, name)
      else
        nil
      end
    end

    def control
      alternatives.first
    end

    def reset_winner
      Split.redis.hdel(:experiment_winner, name)
    end

    def winner=(winner_name)
      Split.redis.hset(:experiment_winner, name, winner_name.to_s)
    end

    def alternatives
      @alternative_names.map {|a| Split::Alternative.find_or_create(a, name)}
    end

    def next_alternative
      winner || alternatives.sort_by{|a| a.participant_count + rand}.first
    end

    def reset
      alternatives.each do |alternative|
        alternative.reset
      end
      reset_winner
    end

    def save
      Split.redis.sadd(:experiments, name)
      @alternative_names.reverse.each {|a| Split.redis.lpush(name, a) }
    end

    def self.all
      Array(Split.redis.smembers(:experiments)).map {|e| find(e)}
    end

    def self.find(name)
      if Split.redis.exists(name)
        self.new(name, *Split.redis.lrange(name, 0, -1))
      else
        raise 'Experiment not found'
      end
    end

    def self.find_or_create(name, *alternatives)
      if Split.redis.exists(name)
        return self.new(name, *Split.redis.lrange(name, 0, -1))
      else
        experiment = self.new(name, *alternatives)
        experiment.save
        return experiment
      end
    end
  end
end