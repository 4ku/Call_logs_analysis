use mydb;

select * from accounts;
select * from call_forwarding;
select * from call_logs;
select * from numbers;
select * from rates;

-- Check uniqueness of UID for accounts
select * from accounts where UID IN (select UID from accounts group by UID having count(*)>1);

-- Check uniqueness of UID for numbers
select * from numbers where UID IN (select UID from numbers group by UID having count(*)>1);

-- Compare two columns UID 
select distinct accounts.UID = numbers.UID from 
	accounts inner join numbers on accounts.UID = numbers.UID;

-- Combine two tables
select a.UID, a.Name, b.phone_number from
(SELECT UID, Name, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum1
FROM accounts) a
join
(SELECT UID, phone_number, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS rownum2
FROM numbers) b 
on a.rownum1 = b.rownum2;

-- get number of rows of call_forwarding table
select count(*) from call_forwarding;

-- get unique values of From and To column
select distinct count(call_forwarding.from) from call_forwarding;
select distinct count(call_forwarding.To) from call_forwarding;


--  check if numbers in To column consist in From column
select distinct call_forwarding.To from call_forwarding 
where call_forwarding.To In (select call_forwarding.From from call_forwarding);

-- find final forwarding numbers
DROP TEMPORARY TABLE IF EXISTS nums_To;
CREATE TEMPORARY TABLE nums_To
select call_forwarding.From , call_forwarding.From as forwarded from  call_forwarding;

Drop procedure if exists while_loop;
DELIMITER //
CREATE procedure while_loop()
  BEGIN
	set @i = 0;
    while(@i < 10) Do
		set @i = @i+1;
        update nums_To, call_forwarding
		set nums_To.forwarded = call_forwarding.To
		where nums_To.forwarded = call_forwarding.From;
    end while;
  END //
  
call while_loop();

update call_forwarding, nums_To
set call_forwarding.To = nums_To.forwarded
where call_forwarding.From = nums_To.From;

-- Make a callforwarding, replace numbers in call_logs
update call_logs, call_forwarding
set call_logs.To = call_forwarding.To
where call_logs.To = call_forwarding.From;

-- Add info about UID_from and UID_To
DROP TEMPORARY TABLE IF EXISTS new_call_logs;
CREATE TEMPORARY TABLE new_call_logs 
		select calls_out.call_id, calls_out.From, calls_out.To,calls_out.UID as UID_From, numbers.UID as UID_To, calls_out.Timestamp_start, calls_out.Timestamp_end  from
		(select * from call_logs where call_dir="out") as calls_out left join numbers
		on calls_out.To = numbers.Phone_number
	union
		select calls_in.call_id, calls_in.From, calls_in.To, numbers.UID as UID_From, calls_in.UID as UID_To, calls_in.Timestamp_start, calls_in.Timestamp_end   from
		(select * from call_logs where call_dir="in") as calls_in left join numbers
		on calls_in.From = numbers.Phone_number;

select * from new_call_logs;

DROP TEMPORARY TABLE IF EXISTS charges;
CREATE TEMPORARY TABLE charges
select new_call_logs.Call_id, new_call_logs.From, new_call_logs.To, new_call_logs.UID_From, new_call_logs.UID_to, 
	((UNIX_TIMESTAMP(Timestamp_end) - UNIX_TIMESTAMP(Timestamp_start))*0.04)  as charge from new_call_logs;

update charges, numbers
set charges.charge = 0
where charges.UID_To = numbers.UID;

-- Charges by each call
select * from charges;
 
-- Total charges
select sum(charge) from charges;


DROP TEMPORARY TABLE IF EXISTS in_UID;
CREATE TEMPORARY TABLE in_UID 
        select UID_To, count(UID_To) as c1 from new_call_logs
		group by UID_To;

DROP TEMPORARY TABLE IF EXISTS out_UID;
CREATE TEMPORARY TABLE out_UID
        select UID_From, count(UID_From) as c2 from new_call_logs
		group by UID_From;
        
-- Top 10 users by income calls
select * from in_UID order by c1 desc Limit 10;

-- Top 10 users by outcome calls
select * from out_UID order by c2 desc Limit 10;

-- Top 10 'active' users
select in_UID.UID_To, (in_UID.c1 + out_UID.c2) as total from in_UID , out_UID
where in_UID.UID_To = out_UID.UID_From order by total desc limit 10 ;

-- Top-10 clients with highest charges
select UID_From, sum(charge) from charges  where UID_From is not null
	group by UID_From order by sum(charge) desc;





