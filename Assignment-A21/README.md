Assignment agenda: Add two independent tasks in the driver: one to perform write operations on the FIFO until it becomes full, and another to read back all the data from the FIFO.

Add two tasks in the driver code

1) write_till_full : this will perfrom series of write operation on FIFO till full flag is set

2) read_till_empty: this will perform series of read operations till empty flag is set.

In the main task of driver call these two task in sequence


```
class driver;

.................

................

 
 task run();
 
    forever
    
    begin
    
    write_till_full();
    
    read_till_empty();
    
    end
    
  endtask
  
...............

...............

endclass
```




Update Driver code to handle these transaction. Expected Test cases should show following behavior.


