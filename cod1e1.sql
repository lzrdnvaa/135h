CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    quantity INT
);

CREATE TABLE operations_log (
    id SERIAL PRIMARY KEY,
    product_id INT,
    operation VARCHAR(10),
    quantity INT,
    operation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
);


CREATE OR REPLACE PROCEDURE update_stock(product_id INT, operation VARCHAR(10), quantity INT)
AS $$
DECLARE
    current_quantity INT;
BEGIN
    IF operation NOT IN ('ADD', 'REMOVE') THEN
        RAISE EXCEPTION 'Недопустимый тип операции: %', operation;
    END IF;

    SELECT quantity INTO current_quantity FROM products WHERE id = product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Товар с id % не найден', product_id;
    END IF;


    IF operation = 'ADD' THEN
        UPDATE products SET quantity = quantity + quantity WHERE id = product_id;
    ELSIF operation = 'REMOVE' THEN
        IF current_quantity - quantity < 0 THEN
            RAISE EXCEPTION 'Недостаточно товара на складе';
        END IF;
        UPDATE products SET quantity = quantity - quantity WHERE id = product_id;
    END IF;

    INSERT INTO operations_log (product_id, operation, quantity) 
    VALUES (product_id, operation, quantity);

    COMMIT;  

EXCEPTION WHEN OTHERS THEN
	ROLLBACK;
    RAISE NOTICE 'Ошибка: %', SQLERRM; 
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION log_quantity_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.quantity <> OLD.quantity THEN
            INSERT INTO operations_log (product_id, operation, quantity)
            VALUES (OLD.id, 'REMOVE', OLD.quantity - NEW.quantity);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER products_quantity_change
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_quantity_change();


CALL update_stock(1, 'ADD', 10);

CALL update_stock(1, 'REMOVE', 5);




SELECT * FROM products;
SELECT * FROM operations_log;