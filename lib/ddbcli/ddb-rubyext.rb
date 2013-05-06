class Array
  def sum
    self.inject {|r, i| r + i }
  end

  def avg
    self.sum / self.length
  end

  def group_by(name, &block)
    item_h = {}

    self.each do |item|
      key = item[name.to_s]
      item_h[key] ||= []
      item_h[key] << item
    end

    return item_h unless block

    new_item_h = {}

    item_h.each do |key, item_list|
      if block.arity == 2
        new_item_h[key] = block.call(item_listm key)
      else
        new_item_h[key] = block.call(item_list)
      end
    end

    return new_item_h
  end

  def method_missing(method_name, *args, &block)
    case method_name.to_s
    when /=\Z/
      self.each {|i| i[method_name.to_s.sub(/=\Z/, '')] = *args }
      self
    else
      self.map {|i| i[method_name.to_s] }
    end
  end
end
