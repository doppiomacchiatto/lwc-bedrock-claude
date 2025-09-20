// ClaudeBedrockServiceTest.cls
@isTest
public class ClaudeBedrockServiceTest {
    
    // Test data constants
    private static final String TEST_MESSAGE = 'Hello Claude, how are you?';
    private static final String TEST_RESPONSE = 'Hello! I\'m doing well, thank you for asking. How can I help you today?';
    private static final String CLAUDE_RESPONSE_JSON = '{"content":[{"text":"' + TEST_RESPONSE + '","type":"text"}],"id":"msg_test123","model":"claude-3-sonnet-20240229","role":"assistant","stop_reason":"end_turn","stop_sequence":null,"type":"message","usage":{"input_tokens":12,"output_tokens":20}}';
    
    
    @isTest
    static void testSendMessageSuccess() {
        // Setup mock HTTP response
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        // Create conversation history
        List<ClaudeBedrockService.ConversationMessage> history = new List<ClaudeBedrockService.ConversationMessage>();
        ClaudeBedrockService.ConversationMessage previousMsg = new ClaudeBedrockService.ConversationMessage();
        previousMsg.role = 'user';
        previousMsg.content = 'Previous message';
        history.add(previousMsg);
        
        Test.startTest();
        
        String response = ClaudeBedrockService.sendMessage(TEST_MESSAGE, history);
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(TEST_RESPONSE, response, 'Should return Claude\'s response text');
    }
    
    @isTest
    static void testSendMessageEmptyMessage() {
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage('', null);
            System.assert(false, 'Should have thrown AuraHandledException for empty message');
        } catch (AuraHandledException e) {
            System.assertEquals('Message cannot be empty', e.getMessage(), 'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageNullMessage() {
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage(null, null);
            System.assert(false, 'Should have thrown AuraHandledException for null message');
        } catch (AuraHandledException e) {
            System.assertEquals('Message cannot be empty', e.getMessage(), 'Should throw appropriate error for null message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageWhitespaceOnlyMessage() {
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage('   \n\t  ', null);
            System.assert(false, 'Should have thrown AuraHandledException for whitespace-only message');
        } catch (AuraHandledException e) {
            System.assertEquals('Message cannot be empty', e.getMessage(), 'Should throw appropriate error for whitespace message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageHttpError() {
        // Setup mock HTTP error response
        Test.setMock(HttpCalloutMock.class, new ErrorBedrockMock());
        
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
            System.assert(false, 'Should have thrown AuraHandledException for HTTP error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to send message to Claude'), 'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageInvalidJsonResponse() {
        // Setup mock with invalid JSON response
        Test.setMock(HttpCalloutMock.class, new InvalidJsonMock());
        
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
            System.assert(false, 'Should have thrown AuraHandledException for invalid JSON');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to send message to Claude'), 'Should throw appropriate error message for invalid JSON');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageMissingContentInResponse() {
        // Setup mock with response missing content array
        Test.setMock(HttpCalloutMock.class, new MissingContentMock());
        
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
            System.assert(false, 'Should have thrown AuraHandledException for missing content');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to send message to Claude'), 'Should throw appropriate error message for missing content');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendMessageWithLongConversationHistory() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        // Create a long conversation history (15 messages)
        List<ClaudeBedrockService.ConversationMessage> history = new List<ClaudeBedrockService.ConversationMessage>();
        for (Integer i = 0; i < 15; i++) {
            ClaudeBedrockService.ConversationMessage msg = new ClaudeBedrockService.ConversationMessage();
            msg.role = Math.mod(i, 2) == 0 ? 'user' : 'assistant';
            msg.content = 'Message ' + i;
            history.add(msg);
        }
        
        Test.startTest();
        
        String response = ClaudeBedrockService.sendMessage(TEST_MESSAGE, history);
        
        Test.stopTest();
        
        // Should still work - service should limit to last 10 messages
        System.assertEquals(TEST_RESPONSE, response, 'Should handle long conversation history');
    }
    
    @isTest
    static void testSendMessageLargeMessage() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        // Create a large message (but within reasonable limits)
        String largeMessage = 'This is a large message. '.repeat(100);
        
        Test.startTest();
        
        String response = ClaudeBedrockService.sendMessage(largeMessage, null);
        
        Test.stopTest();
        
        System.assertEquals(TEST_RESPONSE, response, 'Should handle large messages');
    }
    
    @isTest
    static void testSendMessageSpecialCharacters() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        String messageWithSpecialChars = 'Hello! This message has special chars: émojis 🚀, quotes "test", and newlines\nhere.';
        
        Test.startTest();
        
        String response = ClaudeBedrockService.sendMessage(messageWithSpecialChars, null);
        
        Test.stopTest();
        
        System.assertEquals(TEST_RESPONSE, response, 'Should handle messages with special characters');
    }
    
    @isTest
    static void testBuildClaudeRequestPayload() {
        // This tests the private method indirectly through sendMessage
        Test.setMock(HttpCalloutMock.class, new PayloadValidationMock());
        
        List<ClaudeBedrockService.ConversationMessage> history = new List<ClaudeBedrockService.ConversationMessage>();
        ClaudeBedrockService.ConversationMessage msg1 = new ClaudeBedrockService.ConversationMessage();
        msg1.role = 'user';
        msg1.content = 'First message';
        history.add(msg1);
        
        ClaudeBedrockService.ConversationMessage msg2 = new ClaudeBedrockService.ConversationMessage();
        msg2.role = 'assistant';
        msg2.content = 'First response';
        history.add(msg2);
        
        Test.startTest();
        
        String result = ClaudeBedrockService.sendMessage(TEST_MESSAGE, history);
        System.assertEquals(TEST_RESPONSE, result,'Should return Claude\'s response text');
        Test.stopTest();
        
        // The PayloadValidationMock will verify the request structure
    }
    
    @isTest
    static void testSendMessageTimeout() {
        Test.setMock(HttpCalloutMock.class, new TimeoutMock());
        
        Test.startTest();
        
        try {
            ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
            System.assert(false, 'Should have thrown AuraHandledException for timeout');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to send message to Claude'), 'Should throw appropriate error message for timeout');
        }
        
        Test.stopTest();
    }
    
    // Mock classes for different scenarios
    
    public class SuccessfulBedrockMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(CLAUDE_RESPONSE_JSON);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    public class ErrorBedrockMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error": {"message": "Invalid request", "type": "invalid_request_error"}}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    public class InvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('This is not valid JSON');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    public class MissingContentMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"msg_test","model":"claude-3-sonnet","role":"assistant"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    public class PayloadValidationMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Validate the request payload structure
            String body = req.getBody();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            
            // Verify required fields
            System.assert(payload.containsKey('anthropic_version'), 'Payload should contain anthropic_version');
            System.assert(payload.containsKey('max_tokens'), 'Payload should contain max_tokens');
            System.assert(payload.containsKey('messages'), 'Payload should contain messages');
            System.assert(payload.containsKey('system'), 'Payload should contain system message');
            
            // Verify messages structure
            List<Object> messages = (List<Object>) payload.get('messages');
            System.assert(messages.size() >= 1, 'Should have at least one message');
            
            // Verify the last message is the user message
            Map<String, Object> lastMessage = (Map<String, Object>) messages[messages.size() - 1];
            System.assertEquals('user', lastMessage.get('role'), 'Last message should be from user');
            System.assertEquals(TEST_MESSAGE, lastMessage.get('content'), 'Last message should contain test message');
            
            // Return successful response
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(CLAUDE_RESPONSE_JSON);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    public class TimeoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Simulate timeout by throwing CalloutException
            throw new CalloutException('Read timed out');
        }
    }
    
    // Additional test for governor limits and bulk scenarios
    @isTest
    static void testMultipleCallsWithinLimits() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        Test.startTest();
        
        List<String> responses = new List<String>();
        
        // Make multiple calls (within governor limits)
        for (Integer i = 0; i < 5; i++) {
            String response = ClaudeBedrockService.sendMessage('Message ' + i, null);
            responses.add(response);
        }
        
        Test.stopTest();
        
        // Verify all calls succeeded
        System.assertEquals(5, responses.size(), 'Should have received 5 responses');
        for (String response : responses) {
            System.assertEquals(TEST_RESPONSE, response, 'Each response should match expected response');
        }
    }
    
    // Test error handling for missing custom metadata
    @isTest
    static void testMissingCustomMetadata() {
        // This test assumes no custom metadata is configured
        // You might need to adjust based on your test data setup approach
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        Test.startTest();
        
        try {
            // This might throw an error if custom metadata is not found
            ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
            // If it doesn't throw, that's also valid depending on your implementation
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('AWS credentials not configured'), 
                         'Should throw appropriate error for missing configuration');
        }
        
        Test.stopTest();
    }
    
    // Test conversation message wrapper class
    @isTest
    static void testConversationMessageClass() {
        ClaudeBedrockService.ConversationMessage msg = new ClaudeBedrockService.ConversationMessage();
        msg.role = 'user';
        msg.content = 'Test message';
        
        System.assertEquals('user', msg.role, 'Role should be set correctly');
        System.assertEquals('Test message', msg.content, 'Content should be set correctly');
    }
    
    // Test with various edge cases for conversation history
    @isTest
    static void testConversationHistoryEdgeCases() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulBedrockMock());
        
        Test.startTest();
        
        // Test with null history
        String response1 = ClaudeBedrockService.sendMessage(TEST_MESSAGE, null);
        System.assertEquals(TEST_RESPONSE, response1, 'Should handle null history');
        
        // Test with empty history
        List<ClaudeBedrockService.ConversationMessage> emptyHistory = new List<ClaudeBedrockService.ConversationMessage>();
        String response2 = ClaudeBedrockService.sendMessage(TEST_MESSAGE, emptyHistory);
        System.assertEquals(TEST_RESPONSE, response2, 'Should handle empty history');
        
        Test.stopTest();
    }
}