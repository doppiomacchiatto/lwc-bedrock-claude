// AWSSignatureV4.cls - AWS Signature Version 4 Implementation
public class AWSSignatureV4 {
    
    private static final String ALGORITHM = 'AWS4-HMAC-SHA256';
    private static final String TERMINATION_STRING = 'aws4_request';
    
    public class SignatureResult {
        public String authorization;
        public String dTime;
        public String dia;
    }
    
    public static SignatureResult generateSignature(
        String httpMethod,
        String endpoint,
        String requestUri,
        Map<String, String> headers,
        String payload,
        String accessKey,
        String secretKey,
        String region,
        String service
    ) {
        // Step 1: Create canonical request
        String dTime = Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dia = dTime.substring(0, 8);
        headers.put('x-amz-date', dTime);
        headers.put('host', getHostFromEndpoint(endpoint));
        // Add required headers
       // headers.setHeader('Host', req.getEndpoint().substringAfter('://').substringBefore('/'));
        
        String canonicalRequest = createCanonicalRequest(
            httpMethod, requestUri, headers, payload
        );
        
        // Step 2: Create string to sign
        String credentialScope = dia + '/' + region + '/' + service + '/' + TERMINATION_STRING;
        String stringToSign = createStringToSign(dTime, credentialScope, canonicalRequest);
        
        // Step 3: Calculate signature
        String signature = calculateSignature(secretKey, dia, region, service, stringToSign);
        
        // Step 4: Create authorization header
        String signedHeaders = getSignedHeaders(headers);
        String authorization = ALGORITHM + ' ' +
            'Credential=' + accessKey + '/' + credentialScope + ', ' +
            'SignedHeaders=' + signedHeaders + ', ' +
            'Signature=' + signature;
        
        SignatureResult result = new SignatureResult();
        result.authorization = authorization;
        result.dTime = dTime;
        result.dia = dia;
        
        return result;
    }
    
    private static String createCanonicalRequest(
        String httpMethod,
        String requestUri,
        Map<String, String> headers,
        String payload
    ) {
        // Canonical URI
        String canonicalUri = requestUri;
        if (String.isBlank(canonicalUri)) {
            canonicalUri = '/';
        }
        
        // Canonical Query String (empty for POST requests)
        String canonicalQueryString = '';
        
        // Canonical Headers
        String canonicalHeaders = createCanonicalHeaders(headers);
        
        // Signed Headers
        String signedHeaders = getSignedHeaders(headers);
        
        // Payload Hash
        String payloadHash = hashSHA256(payload);
        
        return httpMethod + '\n' +
               canonicalUri + '\n' +
               canonicalQueryString + '\n' +
               canonicalHeaders + '\n' +
               signedHeaders + '\n' +
               payloadHash;
    }
    
    private static String createCanonicalHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        String canonicalHeaders = '';
        for (String key : sortedKeys) {
            canonicalHeaders += key.toLowerCase() + ':' + 
                               headers.get(key).trim() + '\n';
        }
        
        return canonicalHeaders;
    }
    
    private static String getSignedHeaders(Map<String, String> headers) {
        List<String> sortedKeys = new List<String>(headers.keySet());
        sortedKeys.sort();
        
        List<String> lowerCaseKeys = new List<String>();
        for (String key : sortedKeys) {
            lowerCaseKeys.add(key.toLowerCase());
        }
        
        return String.join(lowerCaseKeys, ';');
    }
    
    private static String createStringToSign(
        String dTime,
        String credentialScope,
        String canonicalRequest
    ) {
        return ALGORITHM + '\n' +
               dTime + '\n' +
               credentialScope + '\n' +
               hashSHA256(canonicalRequest);
    }
    
    private static String calculateSignature(
        String secretKey,
        String dia,
        String region,
        String service,
        String stringToSign
    ) {
        Blob kSecret = Blob.valueOf('AWS4' + secretKey);
        Blob kDate = signHMAC(kSecret, dia);
        Blob kRegion = signHMAC(kDate, region);
        Blob kService = signHMAC(kRegion, service);
        Blob kSigning = signHMAC(kService, TERMINATION_STRING);
        
        Blob signature = signHMAC(kSigning, stringToSign);
        return EncodingUtil.convertToHex(signature);
    }
    
    private static Blob signHMAC(Blob key, String message) {
        return Crypto.generateMac('HmacSHA256', Blob.valueOf(message), key);
    }
    
    private static String hashSHA256(String input) {
        Blob inputBlob = Blob.valueOf(input);
        Blob hash = Crypto.generateDigest('SHA256', inputBlob);
        return EncodingUtil.convertToHex(hash);
    }
    
    private static String getHostFromEndpoint(String endpoint) {
        String host = endpoint;
        if (host.startsWith('https://')) {
            host = host.substring(8);
        } else if (host.startsWith('http://')) {
            host = host.substring(7);
        }
        
        if (host.contains('/')) {
            host = host.substring(0, host.indexOf('/'));
        }
        
        return host;
    }
}