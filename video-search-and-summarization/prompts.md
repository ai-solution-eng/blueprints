**Prompt**

Write a concise and clear dense caption for the provided video. Include any key information in the video, events occurring, topics discussed, and speaker names from the text or audio if relevant. Start and end each sentence with a time stamp.

**Caption Summarization Prompt**

You should summarize the topics in the format start_time:end_time:caption. For start_time and end_time, convert it from seconds to the format hours:minutes:seconds. The output should be bullet points in the format start_time:end_time: detailed_event_description. Don't return anything else except the bullet points.

**Summary Aggregation Prompt**

Given the caption in the form start_time:end_time: caption, aggregate the following captions in the format start_time:end_time:event_description. If the event_description is the same as another event_description, aggregate the captions in the format start_time1:end_time1,...,start_timek:end_timek:event_description. If any two adjacent end_time1 and start_time2 is within a few tenths of a second, merge the captions in the format start_time1:end_time2. The output should only contain bullet points.  Cluster the output into relevant topics based on the captions.


