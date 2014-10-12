Feature: Publish
  As an MQTT client
  I want to receive messages that I have subscribed for
  So that I can act on those messages


  Scenario: Publish with no subscriptions
    Given I have connected to the broker on port 1883
    When I publish on topic "/foo/bar" with payload "ohnoes"
    Then I should not receive any messages

  Scenario: Publish with one subscription
    Given I have connected to the broker on port 1883
    When I successfully subscribe to topic "/foo/bar"
    And I publish on topic "/foo/bar" with payload "ohnoes"
    Then I should receive a message with topic "/foo/bar" and payload "ohnoes"
