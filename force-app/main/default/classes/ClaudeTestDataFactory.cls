// ClaudeTestDataFactory.cls - Utility class for creating test data
@isTest
public class ClaudeTestDataFactory {
    
    // Create conversation history with alternating user/assistant messages
    public static List<ClaudeBedrockService.ConversationMessage> createConversationHistory(Integer messageCount) {
        List<ClaudeBedrockService.ConversationMessage> history = new List<ClaudeBedrockService.ConversationMessage>();
        
        for (Integer i = 0; i < messageCount; i++) {
            ClaudeBedrockService.ConversationMessage msg = new ClaudeBedrockService.ConversationMessage();
            msg.role = Math.mod(i, 2) == 0 ? 'user' : 'assistant';
            msg.content = 'Test message ' + i + ': ' + (msg.role == 'user' ? 'User question' : 'Claude response');
            history.add(msg);
        }
        
        return history;
    }
    
    // Create a realistic conversation history
    public static List<ClaudeBedrockService.ConversationMessage> createRealisticConversation() {
        List<ClaudeBedrockService.ConversationMessage> history = new List<ClaudeBedrockService.ConversationMessage>();
        
        ClaudeBedrockService.ConversationMessage msg1 = new ClaudeBedrockService.ConversationMessage();
        msg1.role = 'user';
        msg1.content = 'Hello Claude, I need help with Salesforce development.';
        history.add(msg1);
        
        ClaudeBedrockService.ConversationMessage msg2 = new ClaudeBedrockService.ConversationMessage();
        msg2.role = 'assistant';
        msg2.content = 'Hello! I\'d be happy to help you with Salesforce development. What specific area are you working on?';
        history.add(msg2);
        
        ClaudeBedrockService.ConversationMessage msg3 = new ClaudeBedrockService.ConversationMessage();
        msg3.role = 'user';
        msg3.content = 'I\'m trying to create a Lightning Web Component that integrates with external APIs.';
        history.add(msg3);
        
        ClaudeBedrockService.ConversationMessage msg4 = new ClaudeBedrockService.ConversationMessage();
        msg4.role = 'assistant';
        msg4.content = 'Great choice! For LWC with external API integration, you\'ll need to consider callouts, error handling, and security. Let me help you with the architecture.';
        history.add(msg4);
        
        return history;
    }
    
    // Create messages with various special characters and edge cases
    public static List<String> createEdgeCaseMessages() {
        return new List<String>{
            'Simple message',
            'Message with "quotes" and \'single quotes\'',
            'Message with\nnewlines\nand\ttabs',
            'Message with émojis 🚀 and unicode characters',
            'Very long message that exceeds normal length to test payload limits: ' + 'Lorem ipsum dolor sit amet. '.repeat(50),
            'Message with JSON-like content: {"key": "value", "number": 123}',
            'Message with HTML <b>tags</b> and &amp; entities',
            'Message with special chars: @#$%^&*()_+-=[]{}|;:,.<>?',
            '',  // Empty string (should be caught by validation)
            '   ',  // Whitespace only (should be caught by validation)
            null  // Null (should be caught by validation)
        };
    }
    
    // Create various AWS Bedrock response scenarios
    public static Map<String, String> getBedrockResponses() {
        return new Map<String, String>{
            'success' => '{"content":[{"text":"Hello! I can help you with that.","type":"text"}],"id":"msg_123","model":"claude-3-sonnet-20240229","role":"assistant","stop_reason":"end_turn","type":"message","usage":{"input_tokens":10,"output_tokens":15}}',
            'long_response' => '{"content":[{"text":"This is a very long response that contains multiple sentences and detailed explanations to test how the system handles large payloads from Claude. The response includes technical details, code examples, and comprehensive guidance that would be typical in a real-world scenario where Claude provides detailed assistance.","type":"text"}],"id":"msg_456","model":"claude-3-sonnet-20240229","role":"assistant","stop_reason":"end_turn","type":"message","usage":{"input_tokens":25,"output_tokens":150}}',
            'empty_content' => '{"content":[],"id":"msg_789","model":"claude-3-sonnet-20240229","role":"assistant","stop_reason":"end_turn","type":"message","usage":{"input_tokens":5,"output_tokens":0}}',
            'malformed_json' => '{"content":[{"text":"Response with malformed JSON"',
            'missing_content' => '{"id":"msg_abc","model":"claude-3-sonnet-20240229","role":"assistant","stop_reason":"end_turn","type":"message","usage":{"input_tokens":5,"output_tokens":10}}',
            'error_response' => '{"error":{"type":"invalid_request_error","message":"The request is invalid"}}',
            'rate_limit_error' => '{"error":{"type":"rate_limit_error","message":"Rate limit exceeded"}}'
        };
    }
    
    // Create HTTP status codes for different scenarios
    public static Map<String, Integer> getHttpStatusCodes() {
        return new Map<String, Integer>{
            'success' => 200,
            'bad_request' => 400,
            'unauthorized' => 401,
            'forbidden' => 403,
            'not_found' => 404,
            'rate_limit' => 429,
            'server_error' => 500,
            'bad_gateway' => 502,
            'service_unavailable' => 503,
            'timeout' => 504
        };
    }
    
    // Create test AWS credentials (fake values for testing)
    public static Map<String, String> getTestAWSCredentials() {
        return new Map<String, String>{
            'access_key' => 'AKIAIOSFODNN7EXAMPLE',
            'secret_key' => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
            'region' => 'us-east-1',
            'model_id' => 'anthropic.claude-3-sonnet-20240229-v1:0'
        };
    }
}