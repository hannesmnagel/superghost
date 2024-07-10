**superghost**


is a word game. 

You can test it on Testflight right now here:
https://testflight.apple.com/join/OzTDTCgF

Please look at the general concept. 
The project is in an early stage of development and there will be breaking changes. 
The server is written entirely in swift using vapor and nginx. It is now https using certbot, but I will implement hmac verification or similiar technologies to secure access. Please do not abuse the API or spam it. That will just worsen the experience of users.

Inspired by a game played on the chalk board, superghost is a word game where you have to add letters so that:

- It doesn't make an entire word

- It could become a word when adding more letters

Players take turns and when you think a player is lying you can challenge the move.
You can add letters in the front or append them. 
Every time you lose, you collect a letter of the word GHOST. When the word is full you can't play for this day any longer online. 

In the beta are features that might be paid in the future. 
