# NOTE: this app has been designed as a demo, NOT a template for production.
# There are more complete reference apps at the Elastic Search-Labs repo: https://github.com/elastic/elasticsearch-labs
import datetime
from datetime import timezone, datetime
import streamlit as st
from elasticsearch import Elasticsearch
import json
import os
import pandas as pd
from langchain_community.llms import Ollama

from langchain.schema import (
    SystemMessage,
    HumanMessage,
)
import time
from PIL import Image
# connection to Elasticsearch and define the specific parameters used in the app
es = Elasticsearch("http://localhost:9200", basic_auth=("elastic", os.environ['ES_LOCAL_PASSWORD']))

kb_index_prefix = 'search-rag'
kb_alias = kb_index_prefix
kb_index_pattern = f'${kb_index_prefix}-*'
kb_index_template_name = 'ragoldberg-v1'


transformer_model = '.elser_model_2_linux-x86_64'
inference_id = 'elser-endpoint'

BASE_URL = "http://localhost:11434"

def read_json_file(file_path):
    with open(file_path, 'r') as file:
        data = json.load(file)
    return data


rag_index_template = read_json_file(f'resources/search-rag-index-template.json')

def init_chat_model():
    llm = Ollama(model=os.environ['MODEL'])
    return llm

# perform a semantic and bm25 keyword search on a specific report
def kb_search(question):
    query = {
        "bool": {
            "should": [
                {
                    "semantic": {
                        "field": "embeddings",
                        "query": question
                    }
                },
                {
                    "match": {
                        "text": question
                    }
                },
                {
                    "match": {
                        "title": question
                    }
                }
            ]
        }
    }

    field_list = ['title', 'text', '_score']
    results = es.search(index=kb_alias, query=query, size=100, fields=field_list, min_score=0)
    response_data = [{"_score": hit["_score"], **hit["_source"]} for hit in results["hits"]["hits"]]
    documents = []
    # Check if there are hits
    if "hits" in results and "total" in results["hits"]:
        total_hits = results["hits"]["total"]
        # Check if there are any hits with a value greater than 0
        if isinstance(total_hits, dict) and "value" in total_hits and total_hits["value"] > 0:
            for hit in response_data:
                doc_data = {field: hit[field] for field in field_list if field in hit}
                documents.append(doc_data)
    return documents


def construct_prompt(question, results):
    for record in results:
        if "_score" in record:
            del record["_score"]
    result = ""
    for item in results:
        result += f"Title: {item.get('title')} , Text: {item.get('text')}\n"

    # interact with the LLM
    # augmented_prompt = f"""Using the context below, answer the query. If the answer isn't present in the context, it's ok to say, "I don't know".
    # Context: {result}
    # Query: {question}"""
    # messages = [
    #     SystemMessage(
    #         content="You are a helpful analyst that answers questions based on the context provided. "
    #                 "When you respond, please cite your source where possible, and always summarise your answers."),
    #     HumanMessage(content=augmented_prompt)
    # ]
    # return messages
    augmented_prompt = f"""
    You are a helpful analyst that answers questions based on the context provided.
    When you respond, please cite your source where possible, and always summarise your answers.
    Using the context below, answer the query. If the answer isn't present in the context, it's ok to say, "I don't know".
    Context: {result}
    Query: {question}"""

    return augmented_prompt


# search form
image = Image.open('images/logo_1.png')
st.image(image, width=150)
st.title("RAGoldberg")
st.header("Search your internal knowledge")
question = st.text_input("Question", placeholder="What would you like to know?")
submitted = st.button("search")

if submitted:
    chat_model = init_chat_model()
    search_results = kb_search(question)
    df_results = pd.DataFrame(search_results)
    with st.status("Searching the data...") as status:
        status.update(label=f'Retrieved {len(search_results)} results from Elasticsearch', state="running")
    with st.chat_message("ai assistant", avatar='🤖'):
        full_response = ""
        message_placeholder = st.empty()
        sent_time = datetime.now(tz=timezone.utc)
        prompt = construct_prompt(question, search_results)
        # current_chat_message = chat_model(prompt).content
        current_chat_message = chat_model(prompt)
        answer_type = 'original'

        for chunk in current_chat_message.split():
            full_response += chunk + " "
            time.sleep(0.05)
            # Add a blinking cursor to simulate typing
            message_placeholder.markdown(full_response + "▌")
        message_placeholder.markdown(full_response)
        # chat_bot.info(current_chat_message)
        received_time = datetime.now(tz=timezone.utc)
        status.update(label="AI response complete!", state="complete")
    # st.write(construct_prompt(question, results))
    string_prompt = str(prompt)
    st.dataframe(df_results)
