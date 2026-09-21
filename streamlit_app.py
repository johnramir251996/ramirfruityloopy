import streamlit as st
from snowflake.snowpark.functions import col
import requests

# App title
st.title(":cup_with_straw: Customize Your Smoothie! :cup_with_straw:")
st.write("Choose the fruits you want in your custom Smoothie!")

# Smoothie name input
name_on_order = st.text_input('Name on Smoothie:')
st.write('The name of your Smoothie will be:', name_on_order)

# Connect to Snowflake and get data
cnx = st.connection("snowflake")
session = cnx.session()
my_dataframe = session.table("smoothies.public.fruit_options").select(col('FRUIT_NAME'), col('SEARCH_ON'))
pd_df = my_dataframe.to_pandas()

# Choose ingredients
ingredients_List = st.multiselect(
    'Choose up to 5 ingredients:',
    pd_df['FRUIT_NAME'].tolist()
)

# Reconfirm name
name_on_order = st.text_input("Enter your name")

if ingredients_List:
    ingredients_string = ''

    for fruit_chosen in ingredients_List:
        ingredients_string += fruit_chosen + ' '
        st.subheader(f"{fruit_chosen} Nutrition Information")

        search_on = pd_df.loc[
            pd_df['FRUIT_NAME'] == fruit_chosen,
            'SEARCH_ON'
        ].iloc[0].strip().lower()
        
        smoothiefroot_response = requests.get(
            f"https://www.smoothiefroot.com/api/fruit/{search_on}"
        )

        if smoothiefroot_response.ok:
            try:
                sf_df = st.dataframe(data=smoothiefroot_response.json(), use_container_width=True)
            except requests.exceptions.JSONDecodeError:
                st.error("❌ The API response is not valid JSON.")
                st.text(smoothiefroot_response.text[:300])
        else:
            st.error(f"❌ API call failed with status {smoothiefroot_response.status_code}")

    # Escape single quotes for SQL
    safe_ingredients = ingredients_string.strip().replace("'", "''")
    safe_name = name_on_order.strip().replace("'", "''")

    my_insert_stmt = f"""
        INSERT INTO smoothies.public.orders (ingredients, name_on_order)
        VALUES ('{safe_ingredients}', '{safe_name}')
    """

    # Optional: Display the query
    # st.code(my_insert_stmt, language="sql")

    time_to_insert = st.button('Submit Order')

    if time_to_insert:
        try:
            session.sql(my_insert_stmt).collect()
            st.success(f"✅ Your Smoothie is ordered, {name_on_order}!")
        except Exception as e:
            st.error("❌ Failed to insert order into Snowflake.")
            st.text(str(e))

    st.stop()
