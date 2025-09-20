// claudeChat.js
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendMessageToClaude from '@salesforce/apex/ClaudeBedrockService.sendMessage';

export default class ClaudeChat extends LightningElement {
    @track messages = [];
    @track isLoading = false;
    @track currentMessage = '';
    
    // Public property for component height (configurable in App Builder)
    @api height = 600;

    connectedCallback() {
        // Add welcome message
        this.messages = [{
            id: 'welcome',
            content: 'Hello! I\'m Claude, your AI assistant. How can I help you today?',
            isUser: false,
            timestamp: new Date().toLocaleTimeString()
        }];
    }

    // Getter to apply dynamic height styling
    get containerStyle() {
        return `height: ${this.height}px;`;
    }

    handleInputChange(event) {
        this.currentMessage = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendMessage();
        }
    }

    async sendMessage() {
        if (!this.currentMessage.trim() || this.isLoading) {
            return;
        }

        const userMessage = this.currentMessage.trim();
        const messageId = Date.now().toString();

        // Add user message to chat
        this.messages = [...this.messages, {
            id: messageId + '_user',
            content: userMessage,
            isUser: true,
            timestamp: new Date().toLocaleTimeString()
        }];

        // Clear input and show loading
        this.currentMessage = '';
        this.isLoading = true;

        // Scroll to bottom
        this.scrollToBottom();

        try {
            // Call Apex method to send message to Claude
            const response = await sendMessageToClaude({ 
                message: userMessage,
                conversationHistory: this.getConversationHistory()
            });

            // Add Claude's response
            this.messages = [...this.messages, {
                id: messageId + '_claude',
                content: response,
                isUser: false,
                timestamp: new Date().toLocaleTimeString()
            }];

        } catch (error) {
            console.error('Error sending message:', error);
            
            // Add error message
            this.messages = [...this.messages, {
                id: messageId + '_error',
                content: 'Sorry, I encountered an error processing your request. Please try again.',
                isUser: false,
                isError: true,
                timestamp: new Date().toLocaleTimeString()
            }];

            this.showToast('Error', 'Failed to send message to Claude', 'error');
        } finally {
            this.isLoading = false;
            this.scrollToBottom();
        }
    }

    getConversationHistory() {
        // Return last 10 messages for context (excluding welcome message)
        return this.messages
            .filter(msg => msg.id !== 'welcome' && !msg.isError)
            .slice(-10)
            .map(msg => ({
                role: msg.isUser ? 'user' : 'assistant',
                content: msg.content
            }));
    }

    clearChat() {
        this.messages = [{
            id: 'welcome',
            content: 'Hello! I\'m Claude, your AI assistant. How can I help you today?',
            isUser: false,
            timestamp: new Date().toLocaleTimeString()
        }];
    }

    scrollToBottom() {
        // Use setTimeout to ensure DOM is updated
        setTimeout(() => {
            const chatContainer = this.template.querySelector('.chat-messages');
            if (chatContainer) {
                chatContainer.scrollTop = chatContainer.scrollHeight;
            }
        }, 100);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    get isInputDisabled() {
        return this.isLoading;
    }

    get sendButtonLabel() {
        return this.isLoading ? 'Sending...' : 'Send';
    }
}