module TeslaApi
  module Stream
    def stream(logger: nil, &receiver)
      Async do |task|
        logger && logger.debug("connecting to #{streaming_endpoint}...")
        Async::WebSocket::Client.connect(streaming_endpoint) do |connection|
          on_timeout = ->(subtask) do
            subtask.sleep TIMEOUT
            logger && logger.debug('read timeout')
            task.stop
          end

          logger && logger.debug("[send] #{streaming_connect_message}")
          connection.write(streaming_connect_message)
          timeout = task.async(&on_timeout)

          while message = connection.read
            timeout.stop
            timeout = task.async(&on_timeout)

            logger && logger.debug("[recv] #{message}")
            case message[:msg_type]
            when 'data:update'
              attributes = message[:value].split(',')

              receiver.call({
                time: DateTime.strptime((attributes[0].to_i/1000).to_s, '%s'),
                speed: attributes[1].to_f,
                odometer: attributes[2].to_f,
                soc: attributes[3].to_f,
                elevation: attributes[4].to_f,
                est_heading: attributes[5].to_f,
                est_lat: attributes[6].to_f,
                est_lng: attributes[7].to_f,
                power: attributes[8].to_f,
                shift_state: attributes[9].to_s,
                range: attributes[10].to_f,
                est_range: attributes[11].to_f,
                heading: attributes[12].to_f
              })
            when 'data:error'
              logger && logger.error("[err] #{message}");
              task.stop
            end
          end
        ensure
          logger && logger.debug('connection stopped')
        end
      end
    end

    private

    TIMEOUT = 30

    def streaming_endpoint
      Async::HTTP::Endpoint.parse(streaming_endpoint_url)
    end

    def streaming_endpoint_url
      'wss://streaming.vn.teslamotors.com/streaming/'
    end

    def streaming_connect_message
      {
        msg_type: 'data:subscribe',
        token: Base64.strict_encode64("#{email}:#{self['tokens'].first}"),
        value: 'speed,odometer,soc,elevation,est_heading,est_lat,est_lng,power,shift_state,range,est_range,heading',
        tag: self['vehicle_id'].to_s,
      }
    end
  end
end
