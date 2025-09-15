import requests

class SendMsg:
    def __init__(self, bot_token, chat_alert, chat_errors , chat_keep_alive):
        self.bot_token = bot_token
        self.chat_alert=chat_alert
        self.chat_errors=chat_errors
        self.chat_keep_alive=chat_keep_alive

    def __send(self, bot_chatID, bot_message):
        if bot_chatID is not None and len(bot_chatID) > 0:
            bot = 'Shufersal_del_bot'
            send_text = 'https://api.telegram.org/bot' + self.bot_token + '/sendMessage?chat_id=' + bot_chatID + '&parse_mode=Markdown&text=' + bot_message
            response = requests.get(send_text)
            res=response.json()
            if not(res['ok']):
                print('Message failed: %s'%(res))
            return res
        return None
    
    def send_alert(self, bot_message):
        return self.__send(self.chat_alert, bot_message)
    
    def send_error(self, bot_message):
        return self.__send(self.chat_errors, bot_message)
    
    def send_keepalive(self, bot_message):
        return self.__send(self.chat_keep_alive, bot_message)