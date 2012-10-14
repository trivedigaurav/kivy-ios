#ifndef __IOS_WRAPPER
#define __IOS_WRAPPER

void ios_open_url(char *url);

typedef void (*ios_send_email_cb)(char *, void *);

int ios_send_email(char *subject, char *text, char *mimetype, char *filename,
	char *filename_alias, ios_send_email_cb callback, void *userdata);

typedef void (*ios_billing_info_cb)(char *sku, char *status, char *title, char *description, double price, void *);

int ios_billing_info(char *sku, ios_billing_info_cb callback, void *userdata);

#endif
