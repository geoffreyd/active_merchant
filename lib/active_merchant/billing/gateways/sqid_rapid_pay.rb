require 'digest'
require 'json'
require 'pp'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SqidRapidPayGateway < Gateway

      self.supported_cardtypes = [:visa, :master]
      self.display_name = 'SqID RapidPay'
      self.money_format = :dollars
      self.default_currency = 'AUD'
      self.supported_countries = ['AU']

      self.test_url = 'https://api.staging.sqidpay.com/post'
      self.live_url = 'https://api.sqidpay.com/post'

      def initialize(options ={})
        requires!(options, :login, :api_key, :pass_phrase)
        super
      end

      # Public: Run a purchase transaction.
      #
      # amount         - The monetary amount of the transaction in cents.
      # payment_method - The payment method or authorization token returned from store.
      # options        - A standard ActiveMerchant options hash:
      #
      #                  :order_id         - The merchant’s order number for this
      #                                      transaction (optional).
      #                  :order_id         - A merchant-supplied identifier for the
      #                                      transaction (optional).
      #                  :description      - A merchant-supplied description of the
      #                                      transaction (optional).
      #                  :currency         - Three letter currency code for the
      #                                      transaction (default: "AUD")
      #                  :billing_address  - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :shipping_address - Standard ActiveMerchant address hash
      #                                      (optional).
      #                  :ip               - The ip of the consumer initiating the
      #                                      transaction (optional).
      #                  :application_id   - A string identifying the application
      #                                      submitting the transaction
      #                                      (default: "https://github.com/activemerchant/active_merchant")
      #
      # Returns an ActiveMerchant::Billing::Response object where authorization is the Transaction ID on success
      def purchase(money, creditcard, options={})
        requires!(options, :billing_address, :email)
        requires!(options[:billing_address], :suburb, :state, :postcode)
        post = {
            methodName: 'processPayment',
            merchantCode: @options[:login],
            apiKey: @options[:api_key],
            referenceID: options[:order_id]
            # customField1: '',
            # customField2: '',
            # customField3: ''
        }
        add_creditcard(post, creditcard, options)
        add_customer_data(post, creditcard, options)
        add_amount(post, money, options)

        post[:hashValue] = Digest::MD5.hexdigest("#{@options[:pass_phrase]}#{post[:amount]}#{@options[:api_key]}")
        commit(post)
      end

      private

      def commit(data)
        # p '%%%%%%%%%%%%%%%%%%%%%%%   %%%%%%%%%%%%%%%%%%%%%%'
        # pp JSON.dump(data)
        # return

        response = parse(ssl_post(test? ? self.test_url : self.live_url, JSON.dump(data), headers))

        Response.new(
            succeeded = success?(response),
            message_from(response),
            response,
            :test => test?,
            :error_code => error_from(succeeded, response),
            :authorization => response['transactionID']
        )
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers
        { 'Content-Type' => 'application/json;charset=UTF-8'}
      end

      def success?(response)
        response['sqidResponseCode'] === 0
      end

      def message_from(response)
        response['providerMessage'] || response['sqidResponseMessage']
      end

      def error_from(succeeded, response)
        succeeded ? nil : response['sqidResponseCode']
      end

      def add_amount(post, money, options)
        post[:amount] = sprintf('%.02f', money.to_s)

        post[:currency] = 'AUD'
      end

      def add_creditcard(post, creditcard, options)
        post[:cardNumber] = creditcard.number
        # post[:card_type] = creditcard.brand
        post[:cardName] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:cardExpiry] = expdate(creditcard)
        post[:cardCSC] = creditcard.verification_value
      end

      def add_customer_data(post, creditcard, options)
        post[:customerEmail] = options[:email]
        post[:customerIP] = options[:ip] if options[:id]

        address = options[:billing_address] || options[:address]
        return if address.nil?

        # post[:company] = address[:company]

        post[:customerName] = address[:name]
        post[:customerHouseStreet] = "#{address[:address1]}, #{address[:address2]}"
        post[:customerCity] = address[:city]
        post[:customerSuburb] = address[:suburb]
        post[:customerState] = address[:state]
        post[:customerPostCode] = address[:postcode]

        post[:customerCountry] = address[:country]
        post[:customerMobile] = address[:phone]     # API only has a "mobile" field, no "phone"
      end

    end
  end
end
