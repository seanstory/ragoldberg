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
def kb_search(keywords, semantic_description):
    min_score = 0.03
    size = 100
    field_list = ['title', '_score', 'url', 'text']
    body = {
        "retriever": {
            "rrf": {
                "retrievers": [
                    {
                        "standard": {
                            "query": {
                                "bool": {
                                    "should": [
                                        {
                                            "query_string": {
                                                "default_field": "title",
                                                "query": keywords
                                            }
                                        }
                                    ]
                                }
                            }
                        }
                    },
                    {
                        "standard": {
                            "query": {
                                "semantic": {
                                    "field": "embeddings",
                                    "query": semantic_description
                                }
                            }
                        }
                    }
                ],
                "rank_window_size": size
            }
        },
        "fields": field_list,
        "size": size
    }
    results = es.search(index=kb_alias, body=body)
    response_data = [{"_score": hit["_score"], **hit["_source"]} for hit in results["hits"]["hits"]]
    documents = []
    # Check if there are hits
    if "hits" in results and "total" in results["hits"]:
        total_hits = results["hits"]["total"]
        # Check if there are any hits with a value greater than 0
        if isinstance(total_hits, dict) and "value" in total_hits and total_hits["value"] > 0:
            for hit in response_data:
                if hit["_score"] > min_score:
                    doc_data = {field: hit[field] for field in field_list if field in hit}
                    documents.append(doc_data)
    return documents


def construct_prompt(question, results):
    for record in results:
        if "_score" in record:
            del record["_score"]
    if (len(results) > 0):
        result = ""
        for item in results:
            result += f"""
            =====
            Title: '{item.get('title')}'
            URL: '{item.get('url')}'
            Text: 
            {item.get('text')}
            
            """

        augmented_prompt = f"""
        You are a helpful, professional, analyst that answers questions.
        When you respond, please cite your source where possible.
        Using the context below, answer the question. If the answer isn't present in the context, it's ok to say, "I don't know".
        Do not make up answers. 
        Not all documents in the context are necessarily relevant. Ignore irrelevant pieces of context.
        -----------------------------------
        Context Documents:
        {result}
        
        -----------------------------------
        Question: {question}"""
    else:
        augmented_prompt = f"""
        You are a helpful, professional, analyst that answers questions.
        When you respond, please cite your source where possible.
        Do not make up answers. 
        
        This is my question for you:
        --------------------
        {question}
        """

    return augmented_prompt


# search form
image = Image.open('images/RAGolberg_banner.png')
st.image(image)
st.title("RAGoldberg")
st.header("Search your internal knowledge")
keywords = st.text_input("Keywords", placeholder="Used for standard keyword search")
semantic_description = st.text_input("Description", placeholder="A plain-language description of the document(s) that might have the information you need")
question = st.text_input("Question", placeholder="What would you like to know?")
submitted = st.button("search")

if submitted:
    chat_model = init_chat_model()
    search_results = kb_search(keywords, semantic_description) if keywords and semantic_description else []
    df_results = pd.DataFrame(search_results, columns=['title', 'url', '_score'])
    with st.status("Searching the data...") as status:
        status.update(label=f'Retrieved {len(search_results)} results from Elasticsearch', state="running")
    if search_results and len(search_results) > 0:
        st.dataframe(df_results)
    with st.chat_message("ai assistant", avatar='https://raw.githubusercontent.com/seanstory/ragoldberg/main/images/RAGoldberg_ico.png'):
        full_response = ""
        message_placeholder = st.empty()
        sent_time = datetime.now(tz=timezone.utc)
        prompt = construct_prompt(question, search_results)
        status.update(label=f'Waiting for a response from the LLM...', state="running")
        current_chat_message = chat_model(prompt)
        answer_type = 'original'

        status.update(label=f'👀 the assistant is responding...', state="running")
        for chunk in current_chat_message.split():
            full_response += chunk + " "
            time.sleep(0.05)
            # Add a blinking cursor to simulate typing
            message_placeholder.markdown(full_response + "▌")
        message_placeholder.markdown(full_response)
        received_time = datetime.now(tz=timezone.utc)
        status.update(label="AI response complete!", state="complete")
    string_prompt = str(prompt)
