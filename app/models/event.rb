class Event < ApplicationRecord

  def self.availabilities(date)
    result = []
    7.times do
      slots = self.by_date_availabilities(date.to_date)
      hash = { date: date, slots: slots }
      result << hash
      date += 1.day
    end
    result
  end

  def self.by_date_availabilities(date)
    today = date.to_s
    tomorrow = (date + 1.day).to_s
    recurring_openings = pick_recurring_openings(date)
    openings = Event.where("starts_at > ? AND ends_at < ? AND kind = ?", today, tomorrow, 'opening')
    all_openings = (recurring_openings + openings)
    opening_slots = day_slots(all_openings)
    appointments = Event.where("starts_at > ? AND ends_at < ? AND kind = ?", today, tomorrow, 'appointment')
    appointment_slots = day_slots(appointments)
    available_slots = opening_slots - appointment_slots
  end

  def self.pick_recurring_openings(date)
    wday = date.wday.to_s
    wday_openings = Event.where(weekly_recurring: true).where("strftime('%w', starts_at) = ?", wday)
  end


  def self.day_slots(events)
    slots = []
    events.each do |event|
      slots.concat(half_hours_slots(event))
    end
    slots.uniq
  end

  def self.half_hours_slots(event)
    slots = []
    return slots unless event.correct?
    start_time = event.starts_at
    end_time = event.ends_at

    # DEALS WHEN STARTS_AT OR ENDS_AT is in between half hours
    modulo_start_time = start_time.min % 30
    modulo_end_time = end_time.min % 30

    if !modulo_start_time.zero?
      if event.kind == 'opening'
        minutes_to_add = 30 - modulo_start_time
        start_time += minutes_to_add.minutes
      else
        minutes_to_substract = modulo_start_time
        start_time -= minutes_to_substract.minutes
      end
    end

    if !modulo_end_time.zero?
      if event.kind == 'appointment'
        minutes_to_add = 30 - modulo_end_time
        end_time += minutes_to_add.minutes
      else
        minutes_to_substract = modulo_end_time
        end_time -= minutes_to_substract.minutes
      end
    end

    while start_time <= end_time - 30.minutes
      slots << start_time.strftime("%-H:%M")
      start_time += 30.minutes
    end
    slots.uniq
  end

  # REJECTS AS INCORRECT EVENTS THOSE WITH ENDING BEFORE START MOMENT OR ON A DIFFERENT DAY
  def correct?
    starts_at < ends_at && starts_at.to_date == ends_at.to_date
  end

end
