Start each script in its own shell or in the same shell like:

```
$ ./rep.rb &
$ ./req.rb
```

Ctrl-C to terminate `req.rb`.
Use `jobs` and `fg %JOBID` to get `rep.rb` back into foreground, then Ctrl-C to terminate it.
