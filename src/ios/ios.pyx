'''
IOS module
==========

IOS module is wrapping some part of the IOS features.

'''

from cpython cimport Py_INCREF, Py_DECREF
from os.path import basename

cdef extern from "ios_wrapper.h":
    ctypedef void (*ios_send_email_cb)(char *, void *)
    ctypedef void (*ios_billing_info_cb)(char *, char *, char *, char *, double, void *)
    int ios_send_email(char *subject, char *text, char *mimetype, char
            *filename, char *filename_alias, ios_send_email_cb cb, void *userdata)
    void ios_open_url(char *url)
    int ios_billing_info(char *sku, ios_billing_info_cb callback, void *userdata)
    void ios_billing_service_start()
    void ios_billing_service_stop()
    void ios_billing_buy(char *sku)
    char *ios_billing_get_purchased_items()
    char *ios_billing_get_pending_message()

cdef void _send_email_done(char *status, void *data):
    cdef object callback = <object>data
    callback(status)
    Py_DECREF(callback)

cdef void _billing_info_done(char *sku, char *status, char *title, char
        *description, double price, void *data):
    cdef object callback = <object>data
    cdef dict resp = None
    if callback is None:
        return
    if <bytes>status == 'ok':
        resp = {
            'title': title,
            'description': description,
            'price': price,
            'sku': sku }
    callback(sku, status, resp)
    Py_DECREF(callback)


#
# Support for webbrowser module
#

class IosBrowser(object):
    def open(self, url, new=0, autoraise=True):
        open_url(url)
    def open_new(self, url):
        open_url(url)
    def open_new_tab(self, url):
        open_url(url)

import webbrowser
webbrowser.register('ios', IosBrowser, None, -1)

#
# API
#

__version__ = (1, 1, 0)

def open_url(url):
    '''Open an URL in Safari

    :Parameters:
        `url`: str
            The url string
    '''
    cdef char *j_url = NULL

    if url is not None:
        if type(url) is unicode:
            url = url.encode('UTF-8')
        j_url = <bytes>url

    ios_open_url(j_url)


def send_email(subject, text, mimetype=None, filename=None, filename_alias=None, callback=None):
    '''Send an email using the IOS api.

    :Parameters:
        `subject`: str
            Subject of the email
        `text`: str
            Content of the email
        `mimetype`: str
            Mimetype of the attachment if exist
        `filename`: str
            Full path of the filename to attach, must be used with mimetype.
        `filename_alias`: str
            Name of the file that will be shown to the user. If none is set, it
            will use the basename of filename.
        `callback`: func(status)
            Callback that can be called when the email interface have been
            removed. A status will be passed as the first argument: "cancelled",
            "saved", "sent", "failed", "unknown", "cannotsend".

    .. note::

        The application must have the window created to be able to use that
        method. Trying to send an email without the application running will
        crash.

    Example for sending a simple hello world::

        ios.send_email('This is my subject', 
            'Hello you!\n\nThis is an hello world.')

    Send a mail with an attachment::

        from os.path import realpath
        ios.send_email('Mail with attachment',
            'Your attachment will be just after this message.',
            mimetype='image/png',
            filename=realpath('mylogo.png'))

    Getting the status of the mail with the callback

        from kivy.app import App

        class EmailApp(App):
            def callback_email(self, status):
                print 'The email have been', status

            def send_email(self, *largs):
                print 'Sending an email'
                ios.send_email('Hello subject', 'World body',
                    callback=self.callback_email)

            def build(self):
                btn = Button(text='Click me')
                btn.bind(on_release=self.send_email)
                return btn

        if __name__ == '__main__':
            EmailApp().run()

    '''
    cdef char *j_mimetype = NULL
    cdef char *j_filename = NULL
    cdef char *j_subject = NULL
    cdef char *j_text = NULL
    cdef char *j_title = NULL
    cdef char *j_filename_alias = NULL

    if subject is not None:
        if type(subject) is unicode:
            subject = subject.encode('UTF-8')
        j_subject = <bytes>subject
    if text is not None:
        if type(text) is unicode:
            text = text.encode('UTF-8')
        j_text = <bytes>text
    if mimetype is not None:
        j_mimetype = <bytes>mimetype
    if filename is not None:
        j_filename = <bytes>filename

        if filename_alias is None:
            filename_alias = basename(filename)
        if type(filename_alias) is unicode:
            filename_alias = filename_alias.encode('UTF-8')
        j_filename_alias = <bytes>filename_alias


    Py_INCREF(callback)

    ret = ios_send_email(j_subject, j_text, j_mimetype, j_filename,
            j_filename_alias, _send_email_done, <void *>callback)
    if ret == 0:
        callback('failed')
        return 0
    elif ret == -1:
        callback('cannotsend')
        return 0

    return 1

def billing_info(sku, callback=None):
    cdef char *j_sku = NULL

    if sku is not None:
        if type(sku) is unicode:
            sku = sku.encode('UTF-8')
        j_sku = <bytes>sku

    Py_INCREF(callback)

    ret = ios_billing_info(j_sku, _billing_info_done, <void *>callback)

    return 1


class BillingService(object):
    BILLING_ACTION_SUPPORTED = 'billingsupported'
    BILLING_ACTION_ITEMSCHANGED = 'itemschanged'
    BILLING_TYPE_INAPP = 'inapp'
    BILLING_TYPE_SUBSCRIPTION = 'subs'

    def __init__(self, callback):
        super(BillingService, self).__init__()
        self.callback = callback
        self.purchased_items = None
        ios_billing_service_start()

    def _stop(self):
        ios_billing_service_stop()

    def buy(self, sku):
        cdef char *j_sku = <bytes>sku
        ios_billing_buy(sku)

    def get_purchased_items(self):
        cdef char *items = NULL
        cdef bytes pitem
        items = ios_billing_get_purchased_items()
        if items == NULL:
            return []
        pitems = items
        ret = {}
        for item in pitems.split('\n'):
            if not item:
                continue
            sku, qt = item.split(',')
            ret[sku] = {'qt': int(qt)}
        return ret

    def check(self, *largs):
        cdef char *message
        cdef bytes pymessage

        while True:
            message = ios_billing_get_pending_message()
            if message == NULL:
                break
            pymessage = <bytes>message
            self._handle_message(pymessage)

        if self.purchased_items is None:
            self._check_new_items()

    def _handle_message(self, message):
        action, data = message.split('|', 1)
        print 'HANDLE MESSAGE------', (action, data)

        if action == 'billingSupported':
            tp, value = data.split('|', 1)
            value = True if value == '1' else False
            self.callback(BillingService.BILLING_ACTION_SUPPORTED, tp, value)

        elif action == 'checkItems':
            self._check_new_items()

    def _check_new_items(self):
        items = self.get_purchased_items()
        if self.purchased_items != items:
            self.purchased_items = items
            self.callback(BillingService.BILLING_ACTION_ITEMSCHANGED,
                    self.purchased_items)
