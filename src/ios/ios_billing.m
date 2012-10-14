/*
 * In-App Billing support
 *
 * Done by following http://troybrant.net/blog/2010/01/in-app-purchases-a-full-walkthrough/
 */

#import <StoreKit/StoreKit.h>
#include "ios_wrapper.h"

#define kInAppPurchaseManagerProductsFetchedNotification @"kInAppPurchaseManagerProductsFetchedNotification"

@interface InAppPurchaseManager : NSObject <SKProductsRequestDelegate>
{
	NSString *sku;
    SKProduct *product;
    SKProductsRequest *request;
	ios_billing_info_cb callback;
	void * userdata;
}

@property(nonatomic, retain) SKProductsRequest *request;
@property(nonatomic, retain) NSString *sku;
@property(nonatomic, assign) ios_billing_info_cb callback;
@property(nonatomic, assign) void *userdata;

@end

#pragma mark -
#pragma mark SKProductsRequestDelegate methods

@implementation InAppPurchaseManager

@synthesize userdata;
@synthesize callback;
@synthesize request;
@synthesize sku;

- (void)requestInfo
{
    NSSet *productIdentifiers = [NSSet setWithObject:sku];
    request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    request.delegate = self;
    [request start];
	NSLog(@"Request information for: %@", sku);
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    product = [products count] == 1 ? [[products firstObject] retain] : nil;
    if (product)
    {
		callback(
			[product.productIdentifier UTF8String],
			"ok",
			[product.localizedTitle UTF8String],
			[product.localizedDescription UTF8String],
			[product.price doubleValue],
			userdata);
    }
    
    for (NSString *invalidProductId in response.invalidProductIdentifiers)
    {
		callback(
			[invalidProductId UTF8String],
			"invalid", NULL, NULL, 0, userdata);
    }
    
    // finally release the reqest we alloc/init’ed in requestProUpgradeProductData
    [self.request release];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kInAppPurchaseManagerProductsFetchedNotification object:self userInfo:nil];
}
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    printf("got error\n");
	NSLog(@"error??");
}

- (void)requestDidFinish:(SKRequest *)request
{
    printf("finished\n");
	NSLog(@"finished??");
}

- (void)dealloc
{
	printf("dealloc\n");
	[super dealloc];
}

@end

int ios_billing_info(char *sku, ios_billing_info_cb callback, void *userdata) {
	InAppPurchaseManager *inAppPm = NULL;
	inAppPm = [[InAppPurchaseManager alloc] init];
	inAppPm.callback = callback;
	inAppPm.userdata = userdata;
	inAppPm.sku = [NSString stringWithCString:(char *)sku encoding:NSUTF8StringEncoding];
	[inAppPm requestInfo];
	return 1;
}
