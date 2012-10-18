#ifndef __IOS_WRAPPER
#define __IOS_WRAPPER

void ios_open_url(char *url);

typedef void (*ios_send_email_cb)(char *, void *);

int ios_send_email(char *subject, char *text, char *mimetype, char *filename,
	char *filename_alias, ios_send_email_cb callback, void *userdata);

typedef void (*ios_billing_info_cb)(char *sku, char *status, char *title, char *description, double price, void *);

/** billing service
 */
int ios_billing_info(char *sku, ios_billing_info_cb callback, void *userdata);
void ios_billing_service_start(void);
void ios_billing_service_stop(void);
void ios_billing_buy(char *sku);
char *ios_billing_get_purchased_items(void);
char *ios_billing_get_pending_message(void);

#endif
