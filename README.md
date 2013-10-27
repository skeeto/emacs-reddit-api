# Emacs Reddit API Wrapper

This library is intended to make it easy to operate reddit's API from
Emacs. Use `reddit-login` to create a session, stored in
`reddit-session`, then use `reddit-get` and `reddit-post` to send
p-lists and receive JSON from reddit.

For example, to login and subscribe to my sandbox subreddit:

```el
(reddit-login "your-username" "your-password")
(reddit-post "/api/subscribe" '(:sr "t5_2s49f" :action sub))
```

API documentation: http://www.reddit.com/dev/api
