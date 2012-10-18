/*
 * In-App Billing support
 *
 * Done by following http://troybrant.net/blog/2010/01/in-app-purchases-a-full-walkthrough/
 *
 * !!!
 * It have been tested only with non-consumable items.
 * Any other type should be implemented
 * !!!
 */

#import <StoreKit/StoreKit.h>
#include "ios_wrapper.h"

#define kInAppPurchaseManagerProductsFetchedNotification @"kInAppPurchaseManagerProductsFetchedNotification"
#define kInAppPurchaseManagerTransactionFailedNotification @"kInAppPurchaseManagerTransactionFailedNotification"
#define kInAppPurchaseManagerTransactionSucceededNotification @"kInAppPurchaseManagerTransactionSucceededNotification"
#define kInAppPurchaseManagerAvailableItems @"kInAppPurchaseManagerAvailableItems"

@interface InAppPurchaseManager : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
{
    SKProduct *product;
    SKProductsRequest *request;
	ios_billing_info_cb callback;
	void * userdata;
	NSMutableArray *messages;
}

// public methods
- (void)loadStore;
- (BOOL)canMakePurchases;
- (void)purchase:(NSString*)sku;
- (NSString *)getPurchasedItems;

@property(nonatomic, retain) SKProductsRequest *request;
@property(nonatomic, assign) ios_billing_info_cb callback;
@property(nonatomic, assign) void *userdata;
@property(nonatomic, assign) NSMutableArray *messages;

@end

#pragma mark -
#pragma mark SKProductsRequestDelegate methods

@implementation InAppPurchaseManager

@synthesize userdata;
@synthesize callback;
@synthesize request;
@synthesize messages;

- (void)requestInfo:(NSString *)sku
{
    NSSet *productIdentifiers = [NSSet setWithObject:sku];
    request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    request.delegate = self;
    [request start];
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
}

- (void)requestDidFinish:(SKRequest *)request
{
}

- (void)dealloc
{
	[super dealloc];
}

//
// call this method once on startup
//
- (void)loadStore
{
    // restarts any purchases if they were interrupted last time the app was open
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

//
// call this before making a purchase
//
- (BOOL)canMakePurchases
{
    return [SKPaymentQueue canMakePayments];
}

//
// do a purchase of any sku you want
//
- (void)purchase:(NSString *)sku
{
    SKPayment *payment = [SKPayment paymentWithProductIdentifier:sku];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

//
// return a list of sku purchased
//
- (NSString *)getPurchasedItems
{
	NSString *items = [[NSUserDefaults standardUserDefaults] stringForKey:kInAppPurchaseManagerAvailableItems];
	if ( items == nil )
		return [[NSString alloc] init];
	return items;
}


//
// saves a record of the transaction by storing the receipt to disk
//
- (void)recordTransaction:(SKPaymentTransaction *)transaction
{
	// add the product id in our available items
	NSString *items = [[NSUserDefaults standardUserDefaults] stringForKey:kInAppPurchaseManagerAvailableItems];
	NSString *item;
	NSArray *listItems, *itemInfos;
	NSString *sku = transaction.payment.productIdentifier;
	int i, found = 0;

	if ( items == nil ) {
		items = sku;
		items = [items stringByAppendingString:@",1"];
	} else {

		// search if the item have already been bought
		listItems = [items componentsSeparatedByString:@"\n"];
		for ( i = 0; i < [listItems count]; i++ ) {
			itemInfos = [listItems objectAtIndex:i];
			item = [[itemInfos componentsSeparatedByString:@","] objectAtIndex:0];
			if ( [item isEqualToString:sku] ) {
				found = 1;
				break;
			}
		}

		// never appended, do it.
		if ( found == 0 ) {
			items = [items stringByAppendingString:@"\n"];
			items = [items stringByAppendingString:transaction.payment.productIdentifier];
			items = [items stringByAppendingString:@",1"];
		}
	}

	// save the transaction receipt to disk
	[[NSUserDefaults standardUserDefaults] setValue:transaction.transactionReceipt forKey:transaction.payment.productIdentifier];
	[[NSUserDefaults standardUserDefaults] setValue:items forKey:kInAppPurchaseManagerAvailableItems];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

//
// removes the transaction from the queue and posts a notification with the transaction result
//
- (void)finishTransaction:(SKPaymentTransaction *)transaction wasSuccessful:(BOOL)wasSuccessful
{
    // remove the transaction from the payment queue.
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:transaction, @"transaction" , nil];
    if (wasSuccessful)
    {
        // send out a notification that we’ve finished the transaction
        [[NSNotificationCenter defaultCenter] postNotificationName:kInAppPurchaseManagerTransactionSucceededNotification object:self userInfo:userInfo];
    }
    else
    {
        // send out a notification for the failed transaction
        [[NSNotificationCenter defaultCenter] postNotificationName:kInAppPurchaseManagerTransactionFailedNotification object:self userInfo:userInfo];
    }
}

//
// called when the transaction was successful
//
- (void)completeTransaction:(SKPaymentTransaction *)transaction
{
    [self recordTransaction:transaction];
    [self finishTransaction:transaction wasSuccessful:YES];
}

//
// called when a transaction has been restored and and successfully completed
//
- (void)restoreTransaction:(SKPaymentTransaction *)transaction
{
    [self recordTransaction:transaction.originalTransaction];
    [self finishTransaction:transaction wasSuccessful:YES];
}

//
// called when a transaction has failed
//
- (void)failedTransaction:(SKPaymentTransaction *)transaction
{
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        // error!
        [self finishTransaction:transaction wasSuccessful:NO];
    }
    else
    {
        // this is fine, the user just cancelled, so don’t notify
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }
}

#pragma mark -
#pragma mark SKPaymentTransactionObserver methods

//
// called when the transaction status is updated
//
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
            default:
                break;
        }
    }
	[messages addObject:@"checkItems|"];
}


@end

static InAppPurchaseManager *manager = NULL;

int ios_billing_info(char *sku, ios_billing_info_cb callback, void *userdata) {
	InAppPurchaseManager *inAppPm = NULL;
	inAppPm = [[InAppPurchaseManager alloc] init];
	inAppPm.callback = callback;
	inAppPm.userdata = userdata;
	NSString *nsku = [NSString stringWithCString:(char *)sku encoding:NSUTF8StringEncoding];
	[inAppPm requestInfo:nsku];
	return 1;
}

void ios_billing_service_start(void) {
	if ( manager == NULL ) {
		manager = [[InAppPurchaseManager alloc] init];
		manager.messages = [[NSMutableArray alloc] initWithCapacity:10];
		[manager loadStore];

		// python-for-android protocol compatibilty
		[manager.messages addObject:@"billingSupported|subs|0"];
		if ( [manager canMakePurchases] ) {
			[manager.messages addObject:@"billingSupported|inapp|1"];
		} else {
			[manager.messages addObject:@"billingSupported|inapp|0"];
		}

	}
}

void ios_billing_service_stop(void) {
}

void ios_billing_buy(char *sku) {
	if ( manager == NULL )
		ios_billing_service_start();
	NSString *nsku = [NSString stringWithCString:(char *)sku encoding:NSUTF8StringEncoding];
	[manager purchase:nsku];
}

char *ios_billing_get_purchased_items(void) {
	if ( manager == NULL )
		return NULL;
	return [[manager getPurchasedItems] UTF8String];
}

char *ios_billing_get_pending_message(void) {
	if ( manager == NULL )
		return NULL;
	if ( [manager.messages count] == 0 )
		return NULL;
	static NSString *msg;
	msg = [manager.messages objectAtIndex:0];
	[manager.messages removeObjectAtIndex:0];
	return [msg UTF8String];
}
